--!strict
-- Efectos visuales de las habilidades de los roles. El servidor (AbilityService, con Combat/AbilityFx)
-- manda qué efecto y dónde, y este cliente lo dibuja: las estelas, partículas y piezas que se mueven
-- cada fotograma se ven fluidas y no cargan la red. Es solo lo que se ve: el daño y los estados los
-- pone el servidor.
--   - Guerrero: estelas de viento en círculo (Torbellino), rastro rojo (Embestida), pose de grito con
--     brillo rojo (Grito de guerra), suelo agrietado con piedras que saltan (Pisotón y la caída del Salto
--     del gorila), la sombra con aro ámbar que avisa dónde cae el Salto y grietas en abanico (Rompehuesos).
--   - Cazador: flechas verdes con estela (Disparo múltiple), diana sobre las presas marcadas, brillo
--     verde suave en el mono atrapado (el Cepo lo pone el servidor), nube que suelta la
--     Lluvia de proyectiles, flecha dorada que atraviesa (Flecha perforante) y, en el Disparo certero, la
--     línea dorada de aviso mientras carga y una flecha blanca y dorada más gruesa.
--   - Mago: bola de fuego roja con bolitas en espiral, monos congelados en bloques de hielo, punto
--     negro y chispa del Parpadeo, rayo que deja una sombra y humo en los monos alcanzados y roca
--     ardiente que cae del cielo sobre un aviso rojo (Meteoro) y rayo de lava naranja del bastón al
--     enemigo mientras dura el atributo "LavaBeamUntil" del mago (Haz volcánico).
--   - Médico: hojas que salen en círculo (Ungüento), dardo amarillo con cola roja, burbuja de escudo
--     con destello amarillo, tótem navajo de madera con gema verde sobre un suelo de hojas, nube lila
--     con "💤" sobre los monos dormidos (Polvo somnífero; "+30 %" si están expuestos) y vapor morado
--     sobre los envenenados (cerbatanas y "Cura de urgencia"). Resurgir: columna y onda verdes con tres
--     coronas de hojas.
-- Los movimientos del propio jugador (Embestida, Torbellino y Parpadeo) los dibuja RoleController al
-- momento con AbilityFxController.play; el servidor se los manda solo a los demás.
-- La diana de las presas, el vapor del veneno y la burbuja del escudo no llegan por el evento: salen de
-- los atributos "MarkedUntil" y "PoisonedUntil" de los monos y "ShieldHealth"/"ShieldUntil" de los
-- jugadores (si la marca es de una mascota, "MarkSource" = "Pet", el pointer: una huella naranja sobre
-- la cabeza en vez de la diana); los iconos de las marcas
-- de combo, de "ComboMarkBy"/"ComboMarkUntil" (Data/Combos). Al cerrar un combo: aro dorado en el
-- jugador y, en el del mago, el hielo que estalla.
-- Guardia (Fase 10, C5; Combat/Guard, efecto "GuardFx"): chispa al bloquear, destello dorado al parar y
-- estallido naranja con esquirlas y grietas al romperse; en la propia, la cámara tiembla (C12). Evasivo (C7, "EvasiveFx"): ráfaga de aire
-- blanco y azul. Esquiva (Fase 15, V3, "DodgeFx"): estela fina, polvo en los pies y sonido de aire.
-- Amago (C8, "FeintFx"): bocanada corta de humo gris delante del pecho.
-- Proyectiles (C9, Combat/Projectiles; efectos "Projectile" y "ProjectileEnd"): los disparos de las armas
-- y las flechas, bolas y dardos de las habilidades vuelan aquí a la hora del servidor (LOOKS: cómo se ve
-- cada uno y qué deja al pararse, como la explosión de la Bola de fuego).
-- Disparo de remate (C9b, Shared/RangedChain): destello del color del remate en el arma al disparar
-- ("WeaponShotFx") y su proyectil ("<estilo>Finisher" en LOOKS): piedra grande con estela de polvo
-- (honda), flecha con punta y estela celestes (arco), bola de energía azul que estalla (bastón) y dardo
-- verde de savia con estela (cerbatana: cura el doble).
-- Entorno (C10): rebote contra muros ("WallBang": grietas en la pared, polvo y piedras) y zonas de peligro
-- de Combat/Zones ("Zone": suelo ardiendo del Meteoro rematado, hielo de la Nova y nube del Polvo).
-- Laboratorio (Fase 13): los disparos de sus cuatro armas ("Lab…" en LOOKS: dardo azul claro, banana
-- amarilla con estela, red y bola de suero morada que cae en arco), el charco de suero ("AcidPuddle") y
-- la red que enreda ("Entangled"). Fase 15, V9: fogonazo propio de cada arma (destello cian, amarillo con
-- humo, bocanada de cuerda y goterón morado; los demás lo ven en "WeaponShotFx", el propio en "LabMuzzle")
-- e impactos con chispas, anillo y disco-red.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Combos = require(ReplicatedStorage.Shared.Data.Combos)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local WeaponAnimations = require(ReplicatedStorage.Shared.Data.WeaponAnimations)
local BodyAnimations = require(script.Parent.Parent.BodyAnimations)
local CameraShake = require(script.Parent.Parent.CameraShake)

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local GRAVITY = Vector3.new(0, -70, 0)
local RING_SEGMENTS = 28
local LEAF_COLORS = {
	Color3.fromRGB(80, 170, 60),
	Color3.fromRGB(110, 200, 70),
	Color3.fromRGB(60, 140, 50),
	Color3.fromRGB(150, 210, 80),
}

local AbilityFxController = {}

local rng = Random.new()
local folder: Folder

-- ===================================== Piezas básicas =====================================

local function piece(name: string, size: Vector3, color: Color3, material: Enum.Material?, transparency: number?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.Neon
	part.Transparency = transparency or 0
	return part
end

local function ball(
	name: string,
	diameter: number,
	color: Color3,
	material: Enum.Material?,
	transparency: number?
): Part
	local part = piece(name, Vector3.one * diameter, color, material, transparency)
	part.Shape = Enum.PartType.Ball
	return part
end

-- Disco plano sobre el suelo.
local function disc(center: Vector3, radius: number, color: Color3, material: Enum.Material, transparency: number): Part
	local part = piece("Disc", Vector3.new(0.15, radius * 2, radius * 2), color, material, transparency)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	return part
end

-- Pieza "part" pegada a "body" (que es la que se mueve) en la posición "offset" relativa a él.
local function weld(body: BasePart, part: BasePart, offset: CFrame)
	part.Anchored = false
	part.Massless = true
	part.CFrame = body.CFrame * offset
	local joint = Instance.new("Weld")
	joint.Part0 = body
	joint.Part1 = part
	joint.C0 = offset
	joint.Parent = part
	part.Parent = body
end

-- Hoja: un elipsoide fino.
local function leaf(scale: number): Part
	local part = piece(
		"Leaf",
		Vector3.new(0.5, 0.08, 1) * scale,
		LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)],
		Enum.Material.SmoothPlastic
	)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function rootOf(model: Instance?): BasePart?
	if not (model and model:IsA("Model") and model.Parent) then
		return nil
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function anchorAt(position: Vector3, seconds: number): Attachment
	local anchor = Instance.new("Attachment")
	anchor.Name = "AbilityFx"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = position
	Debris:AddItem(anchor, seconds)
	return anchor
end

-- Llama a "step" cada fotograma durante "seconds" (alpha va de 0 a 1) y a "done" al final.
local function animate(seconds: number, step: (alpha: number, deltaTime: number) -> (), done: (() -> ())?)
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		elapsed += deltaTime
		local alpha = math.min(elapsed / seconds, 1)
		local ok, message = pcall(step, alpha, deltaTime)
		if not ok then
			-- Aunque falle, se deja todo como estaba (articulaciones, marcas de "en curso").
			connection:Disconnect()
			warn(`AbilityFx: {message}`)
			if done then
				pcall(done)
			end
		elseif alpha >= 1 then
			connection:Disconnect()
			if done then
				done()
			end
		end
	end)
end

-- Desvanece "parts" en "seconds" (tras esperar "delay") y las borra.
local function fadeAway(parts: { BasePart }, seconds: number, delay: number?)
	task.delay(delay or 0, function()
		local tween = TweenInfo.new(seconds)
		for _, part in parts do
			if part.Parent then
				TweenService:Create(part, tween, { Transparency = 1 }):Play()
			end
		end
		task.delay(seconds, function()
			for _, part in parts do
				part:Destroy()
			end
		end)
	end)
end

-- Todas las piezas de "root" (incluida ella), para desvanecerlas juntas.
local function partsOf(root: BasePart): { BasePart }
	local parts: { BasePart } = { root }
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end
	return parts
end

-- Esconde un proyectil al llegar: su estela se queda desvaneciéndose un momento.
local function retire(body: BasePart, seconds: number)
	for _, part in partsOf(body) do
		part.Transparency = 1
	end
	for _, item in body:GetDescendants() do
		if item:IsA("Fire") or item:IsA("ParticleEmitter") or item:IsA("Light") then
			(item :: any).Enabled = false
		end
	end
	Debris:AddItem(body, seconds)
end

-- Cómo se ve un proyectil (efecto "Projectile", C9): la pieza que vuela (con la punta hacia -Z), lo que
-- hace en cada fotograma ("follow", con dónde está y cuánto lleva volando) y lo que deja al pararse
-- ("land", en ese punto).
type Look = {
	body: BasePart,
	follow: ((cframe: CFrame, elapsed: number) -> ())?,
	land: (position: Vector3) -> (),
}

-- Estela con el ancho "width" en el punto "offset" de "part". Mira siempre a la cámara.
local function trail(part: BasePart, offset: Vector3, color: ColorSequence, lifetime: number, width: number): Trail
	local left = Instance.new("Attachment")
	left.Position = offset - Vector3.new(width / 2, 0, 0)
	left.Parent = part
	local right = Instance.new("Attachment")
	right.Position = offset + Vector3.new(width / 2, 0, 0)
	right.Parent = part
	local streak = Instance.new("Trail")
	streak.Attachment0 = left
	streak.Attachment1 = right
	streak.Color = color
	streak.Lifetime = lifetime
	streak.LightEmission = 1
	streak.FaceCamera = true
	streak.Transparency = NumberSequence.new(0.1, 1)
	streak.WidthScale = NumberSequence.new(1, 0.2)
	streak.Parent = part
	return streak
end

local function emitter(
	texture: string,
	color: ColorSequence,
	size: NumberSequence,
	speed: number,
	lifetime: number
): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = texture
	particles.Color = color
	particles.Size = size
	particles.Transparency = NumberSequence.new(0, 1)
	particles.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	particles.Speed = NumberRange.new(speed * 0.5, speed)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.RotSpeed = NumberRange.new(-90, 90)
	particles.Rotation = NumberRange.new(0, 360)
	particles.Drag = 3
	particles.Rate = 0
	return particles
end

-- Ráfaga de "count" partículas en un punto.
local function burst(
	position: Vector3,
	texture: string,
	color: Color3,
	count: number,
	size: number,
	speed: number,
	lifetime: number
)
	local anchor = anchorAt(position, lifetime + 0.5)
	local particles = emitter(texture, ColorSequence.new(color), NumberSequence.new(size, 0), speed, lifetime)
	particles.LightEmission = if texture == SMOKE_TEXTURE then 0 else 1
	particles.Parent = anchor
	particles:Emit(count)
end

-- Destello de luz que se apaga en "seconds".
local function flash(position: Vector3, color: Color3, range: number, brightness: number, seconds: number)
	local anchor = anchorAt(position, seconds + 0.1)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = anchor
	TweenService:Create(light, TweenInfo.new(seconds), { Brightness = 0 }):Play()
end

-- Esfera que crece y se desvanece.
local function swell(
	position: Vector3,
	from: number,
	to: number,
	color: Color3,
	transparency: number,
	seconds: number,
	material: Enum.Material?
)
	local sphere = ball("Swell", from, color, material, transparency)
	sphere.Position = position
	sphere.Parent = folder
	TweenService:Create(sphere, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * to,
		Transparency = 1,
	}):Play()
	Debris:AddItem(sphere, seconds)
end

-- Aro plano que se abre desde "center" (hecho de tramos, para que sea un aro y no un disco).
local function ring(
	center: Vector3,
	fromRadius: number,
	toRadius: number,
	seconds: number,
	color: Color3,
	thickness: number,
	transparency: number
)
	local segments: { Part } = {}
	for index = 1, RING_SEGMENTS do
		local segment = piece("Ring", Vector3.new(thickness, 0.2, 1), color, Enum.Material.Neon, transparency)
		segment.Parent = folder
		segments[index] = segment
	end
	animate(seconds, function(alpha)
		local eased = 1 - (1 - alpha) ^ 2
		local radius = fromRadius + (toRadius - fromRadius) * eased
		local length = math.max(2 * math.pi * radius / RING_SEGMENTS * 1.08, 0.05)
		for index, segment in segments do
			local angle = index / RING_SEGMENTS * 2 * math.pi
			local point = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
			segment.Size = Vector3.new(thickness, 0.2, length)
			segment.CFrame = CFrame.lookAt(point, point + Vector3.new(-math.sin(angle), 0, math.cos(angle)))
			segment.Transparency = transparency + (1 - transparency) * alpha
		end
	end, function()
		for _, segment in segments do
			segment:Destroy()
		end
	end)
end

-- Lanza una pieza por el aire con gravedad y giro; se desvanece al final.
local function fling(part: BasePart, velocity: Vector3, spin: Vector3, seconds: number)
	local base = part.Transparency
	part.Parent = folder
	animate(seconds, function(alpha, deltaTime)
		velocity += GRAVITY * deltaTime
		part.CFrame = (part.CFrame + velocity * deltaTime)
			* CFrame.Angles(spin.X * deltaTime, spin.Y * deltaTime, spin.Z * deltaTime)
		if alpha > 0.7 then
			part.Transparency = base + (1 - base) * (alpha - 0.7) / 0.3
		end
	end, function()
		part:Destroy()
	end)
end

-- Lleva "body" en línea recta de "from" a "to" a "speed" studs/s. "step" recibe su posición en cada
-- fotograma y "arrive" se llama al llegar.
local function fly(
	body: BasePart,
	from: Vector3,
	to: Vector3,
	speed: number,
	step: ((cframe: CFrame, elapsed: number) -> ())?,
	arrive: (() -> ())?
)
	local offset = to - from
	local start = if offset.Magnitude > 0.01 then CFrame.lookAt(from, to) else CFrame.new(from)
	body.CFrame = start
	body.Parent = folder
	local elapsed = 0
	animate(math.max(offset.Magnitude / speed, 0.03), function(alpha, deltaTime)
		elapsed += deltaTime
		local cframe = start + offset * alpha
		body.CFrame = cframe
		if step then
			step(cframe, elapsed)
		end
	end, arrive)
end

local function groundParams(): RaycastParams
	local ignore: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for _, enemy in CollectionService:GetTagged(Config.Combat.EnemyTag) do
		table.insert(ignore, enemy)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

local function groundAt(position: Vector3, params: RaycastParams): Vector3
	local result = Workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return if result then result.Position else position
end

-- Tiembla la cámara del jugador local si está a menos de "reach" de "origin" (más cuanto más cerca; el
-- ajuste "cameraShake" lo suaviza o lo apaga: CombatClient/CameraShake).
local function shake(origin: Vector3, reach: number, strength: number, seconds: number)
	local root = rootOf(Players.LocalPlayer.Character)
	if not root then
		return
	end
	local distance = (root.Position - origin).Magnitude
	if distance > reach then
		return
	end
	CameraShake.play(strength * (1 - distance / reach), seconds)
end

-- Flecha con la punta hacia -Z (la dirección en la que vuela).
local function arrow(shaft: Color3, head: Color3, feathers: Color3, material: Enum.Material): Part
	local body = piece("Arrow", Vector3.new(0.14, 0.14, 2.4), shaft, material)
	local tip = piece("Tip", Vector3.new(0.3, 0.12, 0.6), head, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = tip
	weld(body, tip, CFrame.new(0, 0, -1.35))
	weld(body, piece("Feather", Vector3.new(0.03, 0.35, 0.5), feathers, material), CFrame.new(0, 0, 1))
	weld(body, piece("Feather", Vector3.new(0.35, 0.03, 0.5), feathers, material), CFrame.new(0, 0, 1))
	return body
end

-- ===================================== Guerrero =====================================

-- Torbellino: estelas que dan vueltas a distintas alturas y radios, como un remolino de viento.
local function whirlwind(character: Model?, seconds: number)
	local root = rootOf(character)
	if not root then
		return
	end
	local radius = Config.Abilities.WhirlwindRadius
	local specs = {
		{ radius = 0.4, height = -2, speed = 13, width = 0.9 },
		{ radius = 0.6, height = -0.9, speed = -15, width = 0.6 },
		{ radius = 0.85, height = 0.3, speed = 12, width = 0.8 },
		{ radius = 0.5, height = 1.4, speed = -12, width = 0.5 },
		{ radius = 0.95, height = -1.6, speed = 16, width = 0.5 },
	}
	local color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 232, 190))
	type Arc = { top: Attachment, bottom: Attachment, streak: Trail, angle: number, spec: typeof(specs[1]) }
	local arcs: { Arc } = {}
	for _, spec in specs do
		for _, phase in { 0, math.pi } do
			local top = Instance.new("Attachment")
			top.Parent = Workspace.Terrain
			local bottom = Instance.new("Attachment")
			bottom.Parent = Workspace.Terrain
			local streak = Instance.new("Trail")
			streak.Attachment0 = top
			streak.Attachment1 = bottom
			streak.Color = color
			streak.Lifetime = 0.3
			streak.LightEmission = 0.6
			streak.Transparency = NumberSequence.new(0.15, 1)
			streak.WidthScale = NumberSequence.new(1, 0.4)
			streak.Enabled = false
			streak.Parent = top
			table.insert(
				arcs,
				{ top = top, bottom = bottom, streak = streak, angle = phase + rng:NextNumber(0, 1), spec = spec }
			)
		end
	end
	-- Polvo levantado a los pies.
	local dust =
		emitter(SMOKE_TEXTURE, ColorSequence.new(Color3.fromRGB(205, 185, 150)), NumberSequence.new(1.5, 4), 10, 0.9)
	dust.Acceleration = Vector3.new(0, 4, 0)
	dust.Transparency = NumberSequence.new(0.6, 1)
	dust.Rate = 30
	local feet = anchorAt(root.Position, seconds + 2)
	dust.Parent = feet

	local elapsed = 0
	animate(seconds, function(alpha, deltaTime)
		elapsed += deltaTime
		if not root.Parent then
			return
		end
		local grow = math.min(elapsed / 0.25, 1)
		feet.WorldPosition = root.Position - Vector3.new(0, 2.5, 0)
		for _, arc in arcs do
			arc.angle += arc.spec.speed * deltaTime
			local distance = radius * arc.spec.radius * (0.4 + 0.6 * grow)
			local height = arc.spec.height + math.sin(arc.angle * 2) * 0.3
			local point = root.Position
				+ Vector3.new(math.cos(arc.angle) * distance, height, math.sin(arc.angle) * distance)
			local half = Vector3.new(0, arc.spec.width / 2, 0)
			arc.top.WorldPosition = point + half
			arc.bottom.WorldPosition = point - half
			arc.streak.Enabled = alpha < 1
		end
	end, function()
		dust.Enabled = false
		for _, arc in arcs do
			arc.streak.Enabled = false
			Debris:AddItem(arc.top, 0.4)
			Debris:AddItem(arc.bottom, 0.4)
		end
	end)
end

-- Embestida: un rastro rojo detrás del guerrero mientras carga.
local function charge(character: Model?, seconds: number)
	local root = rootOf(character)
	if not root then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "ChargeTrail"
	top.Position = Vector3.new(0, 1.6, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "ChargeTrail"
	bottom.Position = Vector3.new(0, -2.2, 0)
	bottom.Parent = root
	local streak = Instance.new("Trail")
	streak.Attachment0 = top
	streak.Attachment1 = bottom
	streak.Color = ColorSequence.new(Color3.fromRGB(255, 50, 35), Color3.fromRGB(150, 0, 0))
	streak.Transparency = NumberSequence.new(0.1, 1)
	streak.WidthScale = NumberSequence.new(1, 0.3)
	streak.Lifetime = 0.6
	streak.LightEmission = 0.8
	streak.Parent = top
	local sparks =
		emitter(SPARKLE_TEXTURE, ColorSequence.new(Color3.fromRGB(255, 70, 40)), NumberSequence.new(0.8, 0), 4, 0.5)
	sparks.LightEmission = 1
	sparks.Rate = 50
	sparks.Parent = bottom
	task.delay(seconds + 0.05, function()
		streak.Enabled = false
		sparks.Enabled = false
	end)
	Debris:AddItem(top, seconds + 1)
	Debris:AddItem(bottom, seconds + 1)
end

-- Articulación del personaje que se puede girar desde aquí para hacer una pose. Vale para las
-- articulaciones clásicas (Motor6D: se gira su C0) y para las nuevas de Roblox (AnimationConstraint:
-- se gira su Attachment0); si hay varias activas con ese nombre, se giran todas. "set" aplica un giro
-- (en el espacio de la pieza a la que va) sobre su posición original y "reset" la devuelve.
type PoseJoint = { set: (rotation: CFrame) -> (), reset: () -> () }

local function poseJoint(character: Model, name: string): PoseJoint?
	type Target = { apply: (frame: CFrame) -> (), original: CFrame }
	local targets: { Target } = {}
	for _, candidate in character:GetDescendants() do
		if candidate.Name ~= name then
			continue
		end
		if candidate:IsA("Motor6D") and candidate.Enabled and candidate.Part0 and candidate.Part1 then
			local motor = candidate
			table.insert(targets, {
				original = motor.C0,
				apply = function(frame: CFrame)
					motor.C0 = frame
				end,
			})
		elseif candidate:IsA("AnimationConstraint") and (candidate :: any).Enabled then
			local attachment = (candidate :: any).Attachment0 :: Attachment?
			if attachment then
				table.insert(targets, {
					original = attachment.CFrame,
					apply = function(frame: CFrame)
						attachment.CFrame = frame
					end,
				})
			end
		end
	end
	if #targets == 0 then
		return nil
	end
	return {
		set = function(rotation: CFrame)
			for _, target in targets do
				target.apply(CFrame.new(target.original.Position) * rotation * target.original.Rotation)
			end
		end,
		reset = function()
			for _, target in targets do
				target.apply(target.original)
			end
		end,
	}
end

local warnedNoJoints = false

-- Avisa una vez (solo en Studio) si un personaje no tiene articulaciones que se puedan girar.
local function warnNoJoints(character: Model)
	if RunService:IsStudio() and not warnedNoJoints then
		warnedNoJoints = true
		warn(
			`AbilityFx: {character.Name} no tiene articulaciones R15 que se puedan girar (Motor6D ni AnimationConstraint)`
		)
	end
end

-- Ángulos de la pose de grito (en el espacio de la pieza a la que va cada articulación): brazos en
-- alto en V y la cabeza y el pecho muy atrás, la misma pose que la animación "WarCry"
-- (PlayerAnimationBuilder). Vale para R15 y R6.
local SCREAM_POSE: { [string]: Vector3 } = {
	Neck = Vector3.new(math.rad(38), 0, 0),
	Waist = Vector3.new(math.rad(18), 0, 0),
	LeftShoulder = Vector3.new(math.rad(15), 0, math.rad(-130)),
	RightShoulder = Vector3.new(math.rad(15), 0, math.rad(130)),
	["Left Shoulder"] = Vector3.new(math.rad(15), 0, math.rad(-130)),
	["Right Shoulder"] = Vector3.new(math.rad(15), 0, math.rad(130)),
	LeftElbow = Vector3.new(0, 0, math.rad(-20)),
	RightElbow = Vector3.new(0, 0, math.rad(20)),
}
local SCREAM_SECONDS = 1.1
local screaming: { [Model]: boolean } = {}

-- Mueve las articulaciones del personaje a la pose de grito, con un temblor, y las devuelve a su sitio.
-- Cada cliente lo hace en su copia del personaje, así que lo ven todos.
local function scream(character: Model)
	if screaming[character] then
		return
	end
	type Joint = { joint: PoseJoint, angles: Vector3 }
	local joints: { Joint } = {}
	for name, angles in SCREAM_POSE do
		local joint = poseJoint(character, name)
		if joint then
			table.insert(joints, { joint = joint, angles = angles })
		end
	end
	if #joints == 0 then
		warnNoJoints(character)
		return
	end
	screaming[character] = true
	animate(SCREAM_SECONDS, function(alpha)
		local time = alpha * SCREAM_SECONDS
		local weight = if time < 0.12
			then time / 0.12
			elseif time > SCREAM_SECONDS - 0.25 then (SCREAM_SECONDS - time) / 0.25
			else 1
		weight = math.sin(weight * math.pi / 2)
		local tremble = math.sin(time * 70) * 0.05 * weight
		for _, entry in joints do
			local angles = entry.angles * weight
			entry.joint.set(CFrame.Angles(angles.X + tremble, angles.Y, angles.Z + tremble * 0.5))
		end
	end, function()
		for _, entry in joints do
			entry.joint.reset()
		end
		screaming[character] = nil
	end)
end

-- ===================================== Disparos =====================================
-- El movimiento al disparar un arma a distancia es una animación (WeaponController, Shared/Data/
-- WeaponAnimations). Aquí solo van sus efectos: la bocanada de la cerbatana y el destello del
-- bastón, cuando llega el golpe del disparo ("fxDelay"). Lo lanza el propio cliente al disparar y
-- los demás cuando se lo dice el servidor (CombatService).

-- Bocanada de aire que sale de la boca hacia delante (cerbatana).
local function puffCloud(character: Model)
	local head = character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local cloud = ball("Puff", 0.25, Color3.fromRGB(235, 245, 235), Enum.Material.SmoothPlastic, 0.4)
	cloud.CFrame = head.CFrame * CFrame.new(0.1, -0.2, -0.75)
	cloud.Parent = folder
	TweenService:Create(cloud, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 0.8,
		Transparency = 1,
		CFrame = cloud.CFrame * CFrame.new(0, 0, -0.5),
	}):Play()
	Debris:AddItem(cloud, 0.35)
end

-- Destello del cristal del bastón al lanzar el hechizo (pieza "Crystal" de Shared/WeaponTools).
local function crystalFlash(character: Model)
	local tool = character:FindFirstChildOfClass("Tool")
	local crystal = if tool then tool:FindFirstChild("Crystal") else nil
	if not (crystal and crystal:IsA("BasePart")) then
		return
	end
	local glint = ball("CastFlash", 0.4, crystal.Color, Enum.Material.Neon, 0.15)
	glint.CFrame = crystal.CFrame
	glint.Parent = folder
	TweenService:Create(glint, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 1.8,
		Transparency = 1,
	}):Play()
	Debris:AddItem(glint, 0.3)
end

-- Fogonazo de las armas del Laboratorio (Fase 15, V9), en la boca "part" (la pieza "Muzzle" del arma o su
-- Handle) y con el aspecto de "style" (el proyectil: LabDart, LabBanana, LabNet o LabAcid). Dura menos de
-- 0,25 s. El destello va soldado a la pieza (sigue al arma de la vista, que se mueve cada fotograma); el
-- humo y las chispas se quedan en el aire. La luz vive dentro del destello y se borra con él.
local MUZZLE_LOOKS: { [string]: { color: Color3, glow: number, light: number, seconds: number } } = {
	LabDart = { color = Color3.fromRGB(150, 215, 255), glow = 0.9, light = 0, seconds = 0.1 },
	LabBanana = { color = Color3.fromRGB(255, 225, 60), glow = 2.4, light = 3, seconds = 0.14 },
	LabNet = { color = Color3.fromRGB(205, 190, 150), glow = 1.3, light = 0, seconds = 0.2 },
	LabAcid = { color = Color3.fromRGB(135, 55, 205), glow = 1.1, light = 2, seconds = 0.22 },
}

local function labMuzzleFlash(part: BasePart, style: string)
	local look = MUZZLE_LOOKS[style]
	if not (look and part.Parent) then
		return
	end
	local forward = part.CFrame.UpVector -- el arma apunta con su +Y (Shared/LabWeaponModels)
	local tip = part.Position + forward * (part.Size.Y / 2 + 0.1)
	local isNet = style == "LabNet"
	local isAcid = style == "LabAcid"
	-- El suero no brilla (sin neón, que lo vuelve rosa); el resto, sí. La red es una bocanada pálida.
	local material = if isAcid then Enum.Material.SmoothPlastic else Enum.Material.Neon
	local glow = ball("MuzzleFlash", look.glow * 0.35, look.color, material, if isNet then 0.5 else 0.1)
	weld(part, glow, part.CFrame:ToObjectSpace(CFrame.new(tip)))
	TweenService:Create(glow, TweenInfo.new(look.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * look.glow,
		Transparency = 1,
	}):Play()
	if look.light > 0 then
		local light = Instance.new("PointLight")
		light.Color = look.color
		light.Range = 9
		light.Brightness = look.light
		light.Parent = glow
		TweenService:Create(light, TweenInfo.new(look.seconds), { Brightness = 0 }):Play()
	end
	Debris:AddItem(glow, look.seconds + 0.05)
	if style == "LabDart" then
		burst(tip, SPARKLE_TEXTURE, look.color, 4, 0.3, 6, 0.15)
	elseif style == "LabBanana" then
		-- Bocanada de humo corta, hacia delante.
		burst(tip, SMOKE_TEXTURE, Color3.fromRGB(190, 185, 170), 5, 0.8, 4, 0.25)
		burst(tip, SPARKLE_TEXTURE, look.color, 5, 0.4, 9, 0.15)
	elseif isNet then
		burst(tip, SMOKE_TEXTURE, look.color, 6, 0.7, 5, 0.25)
	else
		-- Goterón y niebla morada.
		local drop = ball("MuzzleDrop", 0.25, look.color, Enum.Material.SmoothPlastic, 0.1)
		drop.CFrame = CFrame.new(tip)
		drop.Parent = folder
		TweenService:Create(drop, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(tip + forward * 0.8 + Vector3.new(0, -0.5, 0)),
			Transparency = 1,
		}):Play()
		Debris:AddItem(drop, 0.25)
		burst(tip, SMOKE_TEXTURE, look.color, 7, 0.9, 3, 0.25)
	end
end

-- El fogonazo de otro jugador: sale de la pieza "Muzzle" del arma que lleva en la mano (o de su Handle).
-- El del propio jugador no va aquí: su fogonazo sale en la vista (FirstPersonController, efecto "LabMuzzle").
local function labShot(style: string): (character: Model) -> ()
	return function(character)
		if character == Players.LocalPlayer.Character then
			return
		end
		local tool = character:FindFirstChildOfClass("Tool")
		local muzzle = if tool then tool:FindFirstChild("Muzzle", true) or tool:FindFirstChild("Handle") else nil
		if muzzle and muzzle:IsA("BasePart") then
			labMuzzleFlash(muzzle, style)
		end
	end
end

local SHOT_FX: { [string]: (character: Model) -> () } = {
	Dart = puffCloud,
	Spell = crystalFlash,
	LabDart = labShot("LabDart"),
	LabBanana = labShot("LabBanana"),
	LabNet = labShot("LabNet"),
	LabAcid = labShot("LabAcid"),
}

-- La animación de disparo de cada arma del Laboratorio (para el retraso del fogonazo hasta el marcador).
local LAB_SHOT_POSE: { [string]: string } = {
	LabDart = "Dart",
	LabBanana = "LabRifle",
	LabNet = "LabHarpoon",
	LabAcid = "LabCannon",
}

-- Color de cada remate (C9b), en el arma al disparar y en su proyectil.
local FINISHER_COLORS: { [string]: Color3 } = {
	Stone = Color3.fromRGB(255, 225, 170),
	Arrow = Color3.fromRGB(120, 220, 255),
	Spell = Color3.fromRGB(110, 160, 255),
	Dart = Color3.fromRGB(90, 230, 110),
}

-- Destello del remate: una chispa que crece en el arma (o en la mano).
local function finisherGlint(character: Model, style: string)
	local tool = character:FindFirstChildOfClass("Tool")
	local handle = if tool then tool:FindFirstChild("Handle") else nil
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local at = if handle and handle:IsA("BasePart") then handle elseif hand and hand:IsA("BasePart") then hand else nil
	if not at then
		return
	end
	local color = FINISHER_COLORS[style] or FINISHER_COLORS.Stone
	local glint = ball("FinisherFlash", 0.5, color, Enum.Material.Neon, 0.1)
	glint.CFrame = at.CFrame
	glint.Parent = folder
	TweenService:Create(glint, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 3,
		Transparency = 1,
	}):Play()
	Debris:AddItem(glint, 0.35)
	burst(at.Position, SPARKLE_TEXTURE, color, 8, 0.6, 8, 0.4)
	flash(at.Position, color, 10, 3, 0.3)
end

-- (personaje, estilo del arma, remate): la bocanada o el destello del disparo y, si es el remate, su
-- chispa de color.
local function weaponShotFx(character: Model?, projectile: string?, finisher: boolean?)
	local key = projectile or "Stone"
	local effect = SHOT_FX[key]
	if not (character and (effect or finisher)) then
		return
	end
	local data = WeaponAnimations[LAB_SHOT_POSE[key] or key]
	task.wait(if data then data.fxDelay or 0 else 0)
	if not character.Parent then
		return
	end
	if effect then
		effect(character)
	end
	if finisher then
		finisherGlint(character, key)
	end
end

-- Grito de guerra: pose de grito, brillo rojo fuerte que se queda suave mientras dura y ondas rojas.
-- La pose es la animación "WarCry" (Data/PlayerAnimations), que reproduce el cliente del guerrero y
-- ven todos; solo si aún no existe se hace aquí por código (scream), que tiembla con un arma en la
-- mano. Nunca las dos: se sumarían.
local function warCry(character: Model?, seconds: number)
	local root = rootOf(character)
	if not (character and root) then
		return
	end
	if not BodyAnimations.has("WarCry") then
		scream(character)
	end
	local old = character:FindFirstChild("WarCryGlow")
	if old then
		old:Destroy()
	end
	local glow = Instance.new("Highlight")
	glow.Name = "WarCryGlow"
	glow.FillColor = Color3.fromRGB(255, 40, 30)
	glow.OutlineColor = Color3.fromRGB(255, 90, 60)
	glow.FillTransparency = 1
	glow.OutlineTransparency = 1
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = character
	TweenService:Create(glow, TweenInfo.new(0.15), { FillTransparency = 0.3, OutlineTransparency = 0 }):Play()
	task.delay(SCREAM_SECONDS, function()
		TweenService:Create(glow, TweenInfo.new(0.6), { FillTransparency = 0.82, OutlineTransparency = 0.5 }):Play()
	end)
	task.delay(math.max(seconds - 0.5, SCREAM_SECONDS + 0.6), function()
		TweenService:Create(glow, TweenInfo.new(0.5), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	end)
	Debris:AddItem(glow, math.max(seconds, SCREAM_SECONDS + 1.1))

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 50, 30)
	light.Range = 18
	light.Brightness = 6
	light.Parent = root
	TweenService:Create(light, TweenInfo.new(1.2), { Brightness = 0 }):Play()
	Debris:AddItem(light, 1.3)

	for wave = 0, 2 do
		task.delay(wave * 0.13, function()
			if root.Parent then
				ring(root.Position + Vector3.new(0, 0.8, 0), 1.5, 14, 0.55, Color3.fromRGB(255, 50, 35), 0.5, 0.2)
			end
		end)
	end
	burst(root.Position + Vector3.new(0, 1.5, 0), SPARKLE_TEXTURE, Color3.fromRGB(255, 60, 40), 20, 1, 14, 0.6)
end

-- Golpe sísmico: grietas que se abren desde el centro, rocas que saltan del suelo, polvo y temblor.
local function quake(center: Vector3, radius: number)
	local params = groundParams()
	local ground = groundAt(center, params)
	local crackColor = Color3.fromRGB(28, 20, 14)
	local lipColor = Color3.fromRGB(105, 82, 60)
	local cracks: { BasePart } = {}

	local crater = disc(ground + Vector3.new(0, 0.06, 0), 2.4, crackColor, Enum.Material.Slate, 0)
	crater.Parent = folder
	table.insert(cracks, crater)

	local count = 10
	for index = 1, count do
		local angle = index / count * 2 * math.pi + rng:NextNumber(-0.25, 0.25)
		local point = ground
		local width = 0.75
		local length = radius * rng:NextNumber(0.6, 0.95)
		local travelled = 0
		local delayTime = 0
		while travelled < length do
			local step = rng:NextNumber(1.6, 3)
			angle += rng:NextNumber(-0.45, 0.45)
			local nextPoint = groundAt(point + Vector3.new(math.cos(angle), 0, math.sin(angle)) * step, params)
			local span = (nextPoint - point).Magnitude
			if span > 0.1 then
				local middle = (point + nextPoint) / 2
				local direction = CFrame.lookAt(middle, nextPoint)
				local lip = piece("CrackLip", Vector3.new(width + 0.4, 0.1, span + 0.3), lipColor, Enum.Material.Slate)
				lip.CFrame = direction + Vector3.new(0, 0.05, 0)
				local crack =
					piece("Crack", Vector3.new(width, 0.12, span + width * 0.5), crackColor, Enum.Material.Slate)
				crack.CFrame = direction + Vector3.new(0, 0.09, 0)
				table.insert(cracks, lip)
				table.insert(cracks, crack)
				task.delay(delayTime, function()
					lip.Parent = folder
					crack.Parent = folder
				end)
				-- Algún trozo de roca levantado al borde de la grieta.
				if rng:NextNumber() < 0.35 then
					local size = rng:NextNumber(0.6, 1.2)
					local rock = piece("Rubble", Vector3.new(size, size * 0.7, size), lipColor, Enum.Material.Slate)
					rock.CFrame = CFrame.new(nextPoint + Vector3.new(0, size * 0.2, 0))
						* CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6), rng:NextNumber(-0.6, 0.6))
					table.insert(cracks, rock)
					task.delay(delayTime, function()
						rock.Parent = folder
					end)
				end
			end
			width = math.max(0.15, width * 0.8)
			delayTime += 0.03
			point = nextPoint
			travelled += step
		end
	end
	fadeAway(cracks, 1, 2.5)

	-- Piedras que saltan del suelo.
	local rockColors = { Color3.fromRGB(120, 95, 70), Color3.fromRGB(95, 80, 65), Color3.fromRGB(140, 120, 95) }
	for _ = 1, 26 do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local size = rng:NextNumber(0.3, 0.8)
		local rock = piece(
			"Debris",
			Vector3.new(size, size * 0.8, size),
			rockColors[rng:NextInteger(1, #rockColors)],
			Enum.Material.Slate
		)
		rock.CFrame = CFrame.new(ground + outward * rng:NextNumber(0, radius * 0.8) + Vector3.new(0, 0.3, 0))
		local velocity = outward * rng:NextNumber(3, 9) + Vector3.new(0, rng:NextNumber(22, 38), 0)
		local spin = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
		task.delay(rng:NextNumber(0, 0.2), fling, rock, velocity, spin, 1.1)
	end

	local dust =
		emitter(SMOKE_TEXTURE, ColorSequence.new(Color3.fromRGB(165, 140, 105)), NumberSequence.new(3, 6), radius, 1.6)
	dust.Transparency = NumberSequence.new(0.35, 1)
	dust.SpreadAngle = Vector2.new(180, 20)
	dust.Acceleration = Vector3.new(0, 3, 0)
	dust.Parent = anchorAt(ground + Vector3.new(0, 1, 0), 2.5)
	dust:Emit(30)

	ring(ground + Vector3.new(0, 0.3, 0), 1, radius, 0.5, Color3.fromRGB(200, 160, 110), 0.8, 0.3)
	shake(ground, radius * 2.5, 1, 0.6)
end

-- Salto del gorila: dónde va a caer. Una sombra que se oscurece y un aro ámbar que se cierra hasta el
-- radio del golpe mientras dura el salto; al caer, el Pisotón lo pone el servidor ("Quake").
local function leapMark(ground: Vector3, radius: number, seconds: number)
	local shadow = disc(
		ground + Vector3.new(0, 0.08, 0),
		radius * 0.35,
		Color3.fromRGB(20, 16, 12),
		Enum.Material.SmoothPlastic,
		0.85
	)
	shadow.Parent = folder
	animate(seconds, function(alpha)
		local size = radius * (0.35 + 0.65 * alpha)
		shadow.Size = Vector3.new(0.15, size * 2, size * 2)
		shadow.Transparency = 0.85 - 0.4 * alpha
	end, function()
		fadeAway({ shadow }, 0.3)
	end)
	ring(ground + Vector3.new(0, 0.25, 0), radius * 1.6, radius, seconds, Color3.fromRGB(255, 180, 60), 0.5, 0.2)
end

-- Rompehuesos: grietas en abanico delante del guerrero (alrededor si es el remate del combo), piedras
-- que saltan y polvo. Llega con el golpe, al acabar la preparación (cuando el arma baja).
local function smash(ground: Vector3, facing: Vector3, range: number, degrees: number)
	local params = groundParams()
	local crackColor = Color3.fromRGB(28, 20, 14)
	local rockColor = Color3.fromRGB(120, 95, 70)
	local cracks: { BasePart } = {}
	local full = degrees >= 360
	local count = if full then 10 else math.max(3, math.round(degrees / 20))
	local half = math.rad(degrees) / 2
	local base = math.atan2(facing.Z, facing.X)
	for index = 1, count do
		local angle = if full then index / count * 2 * math.pi else base - half + (index - 0.5) / count * 2 * half
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local from = groundAt(ground + direction * 1.2, params)
		local tip = groundAt(ground + direction * range * rng:NextNumber(0.7, 1), params)
		local crack = piece(
			"Crack",
			Vector3.new(rng:NextNumber(0.35, 0.6), 0.12, (tip - from).Magnitude),
			crackColor,
			Enum.Material.Slate
		)
		crack.CFrame = CFrame.lookAt((from + tip) / 2, tip) + Vector3.new(0, 0.08, 0)
		crack.Parent = folder
		table.insert(cracks, crack)
		for _ = 1, 2 do
			local size = rng:NextNumber(0.3, 0.7)
			local rock = piece("Debris", Vector3.new(size, size * 0.8, size), rockColor, Enum.Material.Slate)
			rock.CFrame = CFrame.new(ground + direction * rng:NextNumber(1, range * 0.8) + Vector3.new(0, 0.3, 0))
			local velocity = direction * rng:NextNumber(4, 10) + Vector3.new(0, rng:NextNumber(14, 26), 0)
			fling(rock, velocity, Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), 0), 0.9)
		end
	end
	fadeAway(cracks, 0.8, 1.2)
	local dustAt = if full then ground else ground + facing * range * 0.5
	burst(dustAt + Vector3.new(0, 1, 0), SMOKE_TEXTURE, Color3.fromRGB(165, 140, 105), 16, 3, range * 0.8, 1.2)
	if full then
		ring(ground + Vector3.new(0, 0.3, 0), 1, range, 0.4, Color3.fromRGB(200, 160, 110), 0.6, 0.3)
	end
	shake(ground, range * 2.5, 0.7, 0.35)
end

-- ===================================== Cazador =====================================

-- Disparo múltiple: flechas verdes brillantes con estela verde (cada flecha, un proyectil).
local function multiShotLook(): Look
	local green = Color3.fromRGB(70, 230, 100)
	local body = arrow(green, Color3.fromRGB(170, 255, 170), green, Enum.Material.Neon)
	trail(
		body,
		Vector3.new(0, 0, 1.1),
		ColorSequence.new(Color3.fromRGB(120, 255, 140), Color3.fromRGB(30, 160, 60)),
		0.35,
		0.35
	)
	return {
		body = body,
		land = function(position)
			retire(body, 0.4)
			burst(position, SPARKLE_TEXTURE, green, 6, 0.6, 6, 0.4)
		end,
	}
end

-- Marcar presas: onda roja desde el cazador (las dianas salen solas, ver watchMarks).
-- El cepo salta: un anillo naranja se abre por el suelo hasta su radio de captura (los que quedan
-- dentro, atrapados).
local function trapSnap(center: Vector3, radius: number)
	ring(center + Vector3.new(0, 0.3, 0), 1, radius, 0.35, Color3.fromRGB(230, 140, 60), 0.5, 0.35)
end

local function markPrey(center: Vector3, radius: number)
	ring(center - Vector3.new(0, 2, 0), 2, radius, 0.8, Color3.fromRGB(255, 70, 50), 0.6, 0.3)
	burst(center, SPARKLE_TEXTURE, Color3.fromRGB(255, 90, 60), 12, 1, 10, 0.5)
end

-- Diana sobre una presa marcada: un círculo con otro dentro y una cruz, que gira despacio.
local function reticle(model: Model): (BillboardGui?, Frame?)
	local root = rootOf(model)
	if not root then
		return nil, nil
	end
	local _, extents = model:GetBoundingBox()
	local size = math.clamp(math.max(extents.X, extents.Y) * 1.1, 3, 14)
	local red = Color3.fromRGB(255, 60, 45)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PreyReticle"
	gui.Adornee = root
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 300
	gui.Size = UDim2.fromScale(size * 2, size * 2)
	gui.Parent = folder
	TweenService:Create(gui, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.fromScale(size, size) }):Play()

	local spinner = Instance.new("Frame")
	spinner.AnchorPoint = Vector2.new(0.5, 0.5)
	spinner.Position = UDim2.fromScale(0.5, 0.5)
	spinner.Size = UDim2.fromScale(1, 1)
	spinner.BackgroundTransparency = 1
	spinner.Parent = gui
	for _, spec in { { scale = 0.9, thickness = 3 }, { scale = 0.42, thickness = 2 } } do
		local circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = UDim2.fromScale(0.5, 0.5)
		circle.Size = UDim2.fromScale(spec.scale, spec.scale)
		circle.BackgroundTransparency = 1
		circle.Parent = spinner
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = circle
		local stroke = Instance.new("UIStroke")
		stroke.Color = red
		stroke.Thickness = spec.thickness
		stroke.Parent = circle
	end
	for _, lineSize in { UDim2.new(0, 2, 1.1, 0), UDim2.new(1.1, 0, 0, 2) } do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = lineSize
		line.BackgroundColor3 = red
		line.BorderSizePixel = 0
		line.Parent = spinner
	end
	return gui, spinner
end

-- Marca de una mascota (el pointer, PetService): una huella naranja (almohadilla y cuatro dedos) que
-- flota sobre la cabeza del mono, más pequeña que la diana del cazador para no confundirlas.
local function pawMark(model: Model): BillboardGui?
	local root = rootOf(model)
	if not root then
		return nil
	end
	local box, extents = model:GetBoundingBox()
	local orange = Color3.fromRGB(255, 150, 45)
	local dark = Color3.fromRGB(70, 35, 10)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PetMark"
	gui.Adornee = root
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 300
	-- Encima de la cabeza (lo más alto del modelo), medido desde el centro de su pieza raíz.
	gui.StudsOffsetWorldSpace = Vector3.new(0, box.Position.Y + extents.Y / 2 + 1.4 - root.Position.Y, 0)
	gui.Size = UDim2.fromScale(0.5, 0.5)
	gui.Parent = folder
	TweenService:Create(gui, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.fromScale(2.2, 2.2) }):Play()
	local function blob(position: UDim2, size: UDim2)
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = position
		frame.Size = size
		frame.BackgroundColor3 = orange
		frame.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = dark
		stroke.Thickness = 2
		stroke.Parent = frame
	end
	blob(UDim2.fromScale(0.5, 0.7), UDim2.fromScale(0.52, 0.42))
	for _, toe in { { 0.17, 0.42 }, { 0.38, 0.22 }, { 0.62, 0.22 }, { 0.83, 0.42 } } do
		blob(UDim2.fromScale(toe[1], toe[2]), UDim2.fromScale(0.2, 0.24))
	end
	return gui
end

-- Pone y quita las dianas según el atributo "MarkedUntil" de cada enemigo (lo ponen AbilityService y,
-- con "MarkSource" = "Pet", PetService): la diana que gira o la huella de la mascota.
local function watchMarks()
	type Mark = { gui: BillboardGui, spinner: Frame?, pet: boolean }
	local marks: { [Model]: Mark } = {}
	RunService.RenderStepped:Connect(function(deltaTime)
		for _, mark in marks do
			if mark.spinner then
				mark.spinner.Rotation += deltaTime * 40
			end
		end
	end)
	while true do
		local now = Workspace:GetServerTimeNow()
		for _, enemy in CollectionService:GetTagged(Config.Combat.EnemyTag) do
			if enemy:IsA("Model") then
				local untilTime = enemy:GetAttribute("MarkedUntil")
				local marked = typeof(untilTime) == "number" and now < untilTime
				local pet = enemy:GetAttribute("MarkSource") == "Pet"
				local mark = marks[enemy]
				-- La del cazador pisa a la de la mascota (y al revés cuando la suya se acaba).
				if mark and (not marked or mark.pet ~= pet) then
					mark.gui:Destroy()
					marks[enemy] = nil
					mark = nil
				end
				if marked and not mark then
					if pet then
						local gui = pawMark(enemy)
						if gui then
							marks[enemy] = { gui = gui, pet = true }
						end
					else
						local gui, spinner = reticle(enemy)
						if gui and spinner then
							marks[enemy] = { gui = gui, spinner = spinner, pet = false }
						end
					end
				end
			end
		end
		for enemy, mark in marks do
			if not enemy.Parent then
				mark.gui:Destroy()
				marks[enemy] = nil
			end
		end
		task.wait(0.2)
	end
end

-- Mono atrapado en el cepo: un brillo verde suave que aparece, respira y se va.
local function rooted(model: Model?, seconds: number)
	local root = rootOf(model)
	if not (model and root) then
		return
	end
	local old = model:FindFirstChild("RootedGlow")
	if old then
		old:Destroy()
	end
	local glow = Instance.new("Highlight")
	glow.Name = "RootedGlow"
	glow.FillColor = Color3.fromRGB(120, 235, 120)
	glow.OutlineColor = Color3.fromRGB(170, 255, 150)
	glow.FillTransparency = 1
	glow.OutlineTransparency = 1
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = model
	TweenService
		:Create(glow, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { FillTransparency = 0.55, OutlineTransparency = 0.3 })
		:Play()
	task.delay(0.5, function()
		local breathe = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(glow, breathe, { FillTransparency = 0.78 }):Play()
	end)
	task.delay(math.max(seconds - 0.5, 0.5), function()
		TweenService
			:Create(glow, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { FillTransparency = 1, OutlineTransparency = 1 })
			:Play()
	end)
	Debris:AddItem(glow, math.max(seconds, 1) + 0.1)

	local sparkles =
		emitter(SPARKLE_TEXTURE, ColorSequence.new(Color3.fromRGB(150, 255, 140)), NumberSequence.new(0.5, 0), 2, 1.2)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.SpreadAngle = Vector2.new(60, 60)
	sparkles.LightEmission = 1
	sparkles.Rate = 8
	local attachment = Instance.new("Attachment")
	attachment.Name = "RootedSparkles"
	attachment.Parent = root
	sparkles.Parent = attachment
	task.delay(seconds, function()
		sparkles.Enabled = false
	end)
	Debris:AddItem(attachment, seconds + 1.5)
end

-- Lluvia de proyectiles: zona roja en el suelo y una nube encima de la que caen flechas.
local function arrowRain(center: Vector3, radius: number, seconds: number)
	local zone = disc(center + Vector3.new(0, 0.08, 0), radius, Color3.fromRGB(255, 90, 60), Enum.Material.Neon, 0.8)
	zone.Parent = folder
	local height = 24
	local top = center + Vector3.new(0, height, 0)
	local puffs: { BasePart } = {}
	for index = 1, 18 do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local distance = math.sqrt(rng:NextNumber()) * radius * 0.95
		local size = rng:NextNumber(5, 9)
		local shade = if index <= 6 then rng:NextInteger(85, 100) else rng:NextInteger(115, 145)
		local puff = piece(
			"Cloud",
			Vector3.new(size * 1.4, size * 0.75, size * 1.4),
			Color3.fromRGB(shade, shade + 4, shade + 12),
			Enum.Material.SmoothPlastic,
			1
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = puff
		-- Las primeras, más oscuras, forman la panza de la nube.
		local lift = if index <= 6 then rng:NextNumber(-1.5, -0.5) else rng:NextNumber(-0.5, 2)
		puff.Position = top + Vector3.new(math.cos(angle) * distance, lift, math.sin(angle) * distance)
		puff.Parent = folder
		TweenService:Create(puff, TweenInfo.new(0.4), { Transparency = 0.08 }):Play()
		table.insert(puffs, puff)
	end
	table.insert(puffs, zone)

	local params = groundParams()
	task.spawn(function()
		local finish = os.clock() + seconds
		while os.clock() < finish do
			local angle = rng:NextNumber(0, 2 * math.pi)
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle))
				* math.sqrt(rng:NextNumber())
				* radius
				* 0.85
			local landing = groundAt(center + offset, params)
			local from =
				Vector3.new(landing.X + rng:NextNumber(-1.5, 1.5), top.Y - 2, landing.Z + rng:NextNumber(-1.5, 1.5))
			local body = arrow(
				Color3.fromRGB(120, 85, 50),
				Color3.fromRGB(150, 150, 155),
				Color3.fromRGB(235, 235, 225),
				Enum.Material.Wood
			)
			local stuck = landing + (landing - from).Unit * 0.6
			fly(body, from, stuck, 120, nil, function()
				fadeAway(partsOf(body), 0.4, 1.2)
			end)
			task.wait(0.07)
		end
		fadeAway(puffs, 0.8)
	end)
end

-- Flecha perforante: flecha dorada más grande, con una estela blanca larga, que no se para en los monos.
local function piercingShotLook(): Look
	local gold = Color3.fromRGB(255, 205, 80)
	local body = arrow(gold, Color3.fromRGB(255, 250, 220), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
	body.Size = Vector3.new(0.2, 0.2, 3.2)
	trail(
		body,
		Vector3.new(0, 0, 1.4),
		ColorSequence.new(Color3.fromRGB(255, 255, 240), Color3.fromRGB(255, 190, 60)),
		0.6,
		0.5
	)
	return {
		body = body,
		land = function(position)
			retire(body, 0.6)
			burst(position, SPARKLE_TEXTURE, gold, 10, 0.8, 8, 0.5)
		end,
	}
end

-- Disparo certero: mientras carga, una línea dorada fina desde la cabeza del cazador hacia donde apunta
-- (aviso para el apuntado), que se va encendiendo hasta el disparo.
local function trueShotAim(character: Model?, aim: Vector3, seconds: number)
	local head = if character then character:FindFirstChild("Head") else nil
	if not (head and head:IsA("BasePart")) or typeof(aim) ~= "Vector3" or aim.Magnitude < 0.5 then
		return
	end
	local direction = aim.Unit
	local length = Config.Abilities.TrueShotRange
	local params = groundParams()
	local wall = Workspace:Raycast(head.Position, direction * length, params)
	if wall then
		length = (wall.Position - head.Position).Magnitude
	end
	local line =
		piece("AimLine", Vector3.new(0.08, 0.08, length), Color3.fromRGB(255, 215, 90), Enum.Material.Neon, 0.8)
	line.Parent = folder
	animate(math.max(seconds, 0.05), function(alpha)
		if not head.Parent then
			return
		end
		local from = head.Position
		line.CFrame = CFrame.lookAt(from, from + direction) * CFrame.new(0, 0, -length / 2)
		line.Transparency = 0.8 - 0.55 * alpha
		line.Size = Vector3.new(0.08 + 0.1 * alpha, 0.08 + 0.1 * alpha, length)
	end, function()
		line:Destroy()
	end)
end

-- Disparo certero: flecha blanca con punta dorada, más gruesa que la perforante, con estela larga.
local function trueShotLook(): Look
	local gold = Color3.fromRGB(255, 200, 70)
	local body = arrow(Color3.fromRGB(250, 248, 235), gold, gold, Enum.Material.Neon)
	body.Size = Vector3.new(0.28, 0.28, 3.6)
	trail(body, Vector3.new(0, 0, 1.6), ColorSequence.new(Color3.fromRGB(255, 255, 245), gold), 0.9, 0.8)
	return {
		body = body,
		land = function(position)
			retire(body, 0.9)
			burst(position, SPARKLE_TEXTURE, gold, 18, 1, 12, 0.6)
			flash(position, gold, 14, 5, 0.3)
		end,
	}
end

-- ===================================== Mago =====================================

-- Bola de fuego: bola roja en llamas que va recta; tres bolitas giran a su alrededor y dejan una
-- espiral. Al pararse, explosión del radio "splash".
local function fireballLook(splash: number): Look
	local core = ball("Fireball", 1.5, Color3.fromRGB(255, 45, 25))
	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(255, 70, 30)
	fire.SecondaryColor = Color3.fromRGB(255, 190, 60)
	fire.Size = 4
	fire.Heat = 2
	fire.Parent = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 80, 40)
	light.Range = 12
	light.Brightness = 3
	light.Parent = core
	trail(core, Vector3.zero, ColorSequence.new(Color3.fromRGB(255, 60, 30), Color3.fromRGB(255, 150, 50)), 0.3, 1.2)

	local orbs: { Part } = {}
	for _ = 1, 3 do
		local orb = ball("Orb", 0.45, Color3.fromRGB(255, 180, 70))
		trail(
			orb,
			Vector3.zero,
			ColorSequence.new(Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 60, 20)),
			0.6,
			0.35
		)
		table.insert(orbs, orb)
	end

	return {
		body = core,
		follow = function(cframe, elapsed)
			for index, orb in orbs do
				local angle = elapsed * 16 + index * 2 * math.pi / 3
				orb.CFrame = cframe * CFrame.new(math.cos(angle) * 1.3, math.sin(angle) * 1.3, 0)
				orb.Parent = folder
			end
		end,
		land = function(position)
			retire(core, 0.4)
			for _, orb in orbs do
				if orb.Parent then
					retire(orb, 0.7)
				else
					orb:Destroy()
				end
			end
			swell(position, 1, splash * 2, Color3.fromRGB(255, 100, 30), 0.15, 0.35)
			swell(position, 1, splash, Color3.fromRGB(255, 230, 120), 0, 0.25)
			local flames = emitter(
				FIRE_TEXTURE,
				ColorSequence.new(Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 50, 20)),
				NumberSequence.new(3, 0),
				splash * 2,
				0.6
			)
			flames.LightEmission = 1
			flames.Parent = anchorAt(position, 1.2)
			flames:Emit(30)
			burst(position, SMOKE_TEXTURE, Color3.fromRGB(70, 60, 55), 12, 4, splash, 1.2)
			flash(position, Color3.fromRGB(255, 120, 40), splash * 3, 6, 0.5)
			shake(position, 25, 0.4, 0.3)
		end,
	}
end

-- Nova de hielo: aros helados, pinchos de hielo que salen del suelo y escarcha.
local function frostNova(center: Vector3, radius: number)
	local params = groundParams()
	local ground = groundAt(center, params)
	ring(ground + Vector3.new(0, 0.3, 0), 1, radius, 0.45, Color3.fromRGB(170, 225, 255), 1, 0.1)
	task.delay(
		0.1,
		ring,
		ground + Vector3.new(0, 0.4, 0),
		1,
		radius * 0.8,
		0.45,
		Color3.fromRGB(255, 255, 255),
		0.5,
		0.2
	)
	burst(center, SPARKLE_TEXTURE, Color3.fromRGB(200, 235, 255), 40, 1, radius * 1.5, 0.7)
	flash(center, Color3.fromRGB(150, 210, 255), radius * 2, 4, 0.6)

	local spikes: { BasePart } = {}
	for _ = 1, 14 do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local distance = radius * rng:NextNumber(0.35, 1)
		local height = rng:NextNumber(1.5, 3)
		local base = groundAt(ground + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance, params)
		local spike =
			piece("IceSpike", Vector3.new(0.6, height, 0.6), Color3.fromRGB(190, 230, 255), Enum.Material.Ice, 0.15)
		local tilt = CFrame.new(base)
			* CFrame.Angles(0, -angle, 0)
			* CFrame.Angles(0, 0, math.rad(-20))
			* CFrame.Angles(0, math.rad(45), 0)
		spike.CFrame = tilt * CFrame.new(0, -height / 2, 0)
		spike.Parent = folder
		table.insert(spikes, spike)
		task.delay(distance / radius * 0.3, function()
			TweenService
				:Create(
					spike,
					TweenInfo.new(0.15, Enum.EasingStyle.Back),
					{ CFrame = tilt * CFrame.new(0, height / 2, 0) }
				)
				:Play()
		end)
	end
	fadeAway(spikes, 0.6, 1.2)
end

-- Mono congelado: un bloque de hielo que lo envuelve (y le sigue) y se rompe en trozos al final.
local function frozen(model: Model?, seconds: number)
	if not (model and model.Parent) then
		return
	end
	local box, extents = model:GetBoundingBox()
	local offset = model:GetPivot():ToObjectSpace(box)
	local size = extents + Vector3.new(0.8, 0.5, 0.8)
	local block = piece("IceBlock", size * 0.3, Color3.fromRGB(150, 210, 255), Enum.Material.Glass, 0.45)
	block.Reflectance = 0.2
	block.CFrame = model:GetPivot() * offset
	block.Parent = folder
	TweenService:Create(block, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = size }):Play()

	-- Cristales de hielo alrededor de la base.
	type Crystal = { part: BasePart, offset: CFrame }
	local crystals: { Crystal } = {}
	for index = 1, 6 do
		local angle = index / 6 * 2 * math.pi + rng:NextNumber(-0.3, 0.3)
		local height = rng:NextNumber(1, 2)
		local crystal =
			piece("IceCrystal", Vector3.new(0.5, height, 0.5), Color3.fromRGB(200, 235, 255), Enum.Material.Ice, 0.1)
		local spot = CFrame.new(math.cos(angle) * size.X / 2, -size.Y / 2 + height * 0.3, math.sin(angle) * size.Z / 2)
			* CFrame.Angles(0, -angle, 0)
			* CFrame.Angles(0, 0, math.rad(-25))
			* CFrame.Angles(0, math.rad(45), 0)
		crystal.Parent = folder
		table.insert(crystals, { part = crystal, offset = spot })
	end
	local mist =
		emitter(SMOKE_TEXTURE, ColorSequence.new(Color3.fromRGB(230, 245, 255)), NumberSequence.new(1, 2.5), 1.5, 1.4)
	mist.Transparency = NumberSequence.new(0.6, 1)
	mist.Rate = 6
	local mistAnchor = Instance.new("Attachment")
	mistAnchor.Parent = block
	mist.Parent = mistAnchor

	local function shatter()
		local center = block.Position
		for _ = 1, 10 do
			local shard = piece(
				"IceShard",
				Vector3.one * rng:NextNumber(0.3, 0.7),
				Color3.fromRGB(190, 230, 255),
				Enum.Material.Ice,
				0.2
			)
			shard.CFrame =
				CFrame.new(center + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)))
			local velocity = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(8, 18), rng:NextNumber(-10, 10))
			fling(
				shard,
				velocity,
				Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-6, 6), rng:NextNumber(-6, 6)),
				0.8
			)
		end
		burst(center, SPARKLE_TEXTURE, Color3.fromRGB(210, 240, 255), 14, 0.8, 8, 0.5)
		block:Destroy()
		for _, crystal in crystals do
			crystal.part:Destroy()
		end
	end

	local broken = false
	animate(seconds, function()
		if broken then
			return
		end
		if not model.Parent then
			broken = true
			shatter()
			return
		end
		block.CFrame = model:GetPivot() * offset
		for _, crystal in crystals do
			crystal.part.CFrame = block.CFrame * crystal.offset
		end
	end, function()
		if not broken then
			shatter()
		end
	end)
end

-- Parpadeo: el mago se encoge en un punto negro donde estaba y aparece con una chispa.
local function blink(from: Vector3, to: Vector3)
	local dot = ball("BlinkDot", 3.2, Color3.fromRGB(8, 6, 12), Enum.Material.SmoothPlastic)
	dot.Position = from
	dot.Parent = folder
	TweenService
		:Create(dot, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.one * 0.4 })
		:Play()
	task.delay(0.33, function()
		TweenService:Create(dot, TweenInfo.new(0.1), { Size = Vector3.one * 0.05, Transparency = 1 }):Play()
	end)
	Debris:AddItem(dot, 0.5)

	swell(to, 0.3, 2.4, Color3.fromRGB(255, 245, 200), 0, 0.25)
	burst(to, SPARKLE_TEXTURE, Color3.fromRGB(255, 235, 160), 14, 1, 10, 0.5)
	flash(to, Color3.fromRGB(255, 230, 160), 12, 4, 0.3)
end

-- Humo oscuro que sale de un mono alcanzado por el rayo, con alguna chispa.
local function smoke(model: Model)
	local root = rootOf(model)
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "ShockSmoke"
	attachment.Parent = root
	local puffs = emitter(
		SMOKE_TEXTURE,
		ColorSequence.new(Color3.fromRGB(60, 60, 65), Color3.fromRGB(150, 150, 155)),
		NumberSequence.new(0.8, 2.8),
		4,
		1.8
	)
	puffs.EmissionDirection = Enum.NormalId.Top
	puffs.SpreadAngle = Vector2.new(25, 25)
	puffs.Acceleration = Vector3.new(0, 3, 0)
	puffs.Transparency = NumberSequence.new(0.2, 1)
	puffs.Drag = 1
	puffs.Rate = 20
	puffs.Parent = attachment
	local sparks =
		emitter(SPARKLE_TEXTURE, ColorSequence.new(Color3.fromRGB(255, 240, 150)), NumberSequence.new(0.5, 0), 8, 0.3)
	sparks.LightEmission = 1
	sparks.Rate = 12
	sparks.Parent = attachment
	task.delay(0.8, function()
		sparks.Enabled = false
	end)
	task.delay(2.2, function()
		puffs.Enabled = false
	end)
	Debris:AddItem(attachment, 4.5)
end

-- Rayo encadenado (un salto): un rayo quebrado muy brillante que se apaga dejando su sombra, que se
-- desvanece; el mono alcanzado echa humo.
local function lightning(from: Vector3, to: Vector3, target: Model?)
	local offset = to - from
	local distance = offset.Magnitude
	if distance < 0.5 then
		return
	end
	local frame = CFrame.lookAt(from, to)
	local amplitude = math.min(1.8, distance * 0.08)
	local function jagged(a: Vector3, b: Vector3, count: number, spread: number): { Vector3 }
		local points = { a }
		for index = 1, count - 1 do
			local jitter = frame.RightVector * rng:NextNumber(-1, 1) * spread
				+ frame.UpVector * rng:NextNumber(-1, 1) * spread
			table.insert(points, a + (b - a) * (index / count) + jitter)
		end
		table.insert(points, b)
		return points
	end
	local cores: { BasePart } = {}
	local glows: { BasePart } = {}
	local function draw(points: { Vector3 }, width: number)
		for index = 1, #points - 1 do
			local a, b = points[index], points[index + 1]
			local length = (b - a).Magnitude
			local cframe = CFrame.lookAt((a + b) / 2, b)
			local core = piece("Bolt", Vector3.new(width, width, length + width), Color3.fromRGB(255, 255, 240))
			core.CFrame = cframe
			core.Parent = folder
			table.insert(cores, core)
			local glow = piece(
				"BoltGlow",
				Vector3.new(width * 3, width * 3, length + width),
				Color3.fromRGB(255, 235, 110),
				nil,
				0.55
			)
			glow.CFrame = cframe
			glow.Parent = folder
			table.insert(glows, glow)
		end
	end
	local main = jagged(from, to, math.clamp(math.floor(distance / 2.5), 4, 16), amplitude)
	draw(main, 0.22)
	-- Un par de ramas cortas.
	for _ = 1, 2 do
		local start = main[rng:NextInteger(2, math.max(2, #main - 1))]
		local reach = frame.LookVector * rng:NextNumber(2, 4)
			+ frame.RightVector * rng:NextNumber(-3, 3)
			+ frame.UpVector * rng:NextNumber(-3, 3)
		draw(jagged(start, start + reach, 2, 0.6), 0.12)
	end
	flash(to, Color3.fromRGB(255, 245, 190), 20, 8, 0.4)
	flash(from, Color3.fromRGB(255, 245, 190), 10, 3, 0.25)
	burst(to, SPARKLE_TEXTURE, Color3.fromRGB(255, 240, 150), 12, 0.8, 12, 0.4)

	-- Parpadea y se apaga dejando una sombra oscura que se desvanece.
	task.delay(0.06, function()
		for _, glow in glows do
			glow.Transparency = 0.85
		end
	end)
	task.delay(0.1, function()
		for _, glow in glows do
			glow.Transparency = 0.5
		end
	end)
	task.delay(0.22, function()
		for _, glow in glows do
			glow:Destroy()
		end
		for _, core in cores do
			core.Material = Enum.Material.SmoothPlastic
			core.Color = Color3.fromRGB(35, 33, 42)
			core.Size = Vector3.new(0.35, 0.35, core.Size.Z)
			core.Transparency = 0.3
		end
		fadeAway(cores, 0.9)
	end)
	if target then
		smoke(target)
	end
end

-- Meteoro: aviso rojo en el suelo mientras cae del cielo una roca ardiente; al llegar, explosión de
-- fuego y suelo agrietado. El suelo ardiendo del remate es una zona ("Zone" "Fire").
local function meteor(center: Vector3, radius: number, delay: number)
	local warning = disc(center + Vector3.new(0, 0.1, 0), radius, Color3.fromRGB(255, 70, 30), Enum.Material.Neon, 1)
	warning.Parent = folder
	TweenService:Create(warning, TweenInfo.new(delay, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 0.45,
	}):Play()

	local sky = center + Vector3.new(rng:NextNumber(-14, 14), 70, rng:NextNumber(-14, 14))
	local rock = ball("Meteor", 3, Color3.fromRGB(70, 35, 25), Enum.Material.Slate)
	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(255, 90, 30)
	fire.SecondaryColor = Color3.fromRGB(255, 200, 70)
	fire.Size = 7
	fire.Heat = 9
	fire.Parent = rock
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 110, 40)
	light.Range = 18
	light.Brightness = 3
	light.Parent = rock
	trail(rock, Vector3.zero, ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 60, 20)), 0.5, 2.5)
	fly(rock, sky, center, (center - sky).Magnitude / math.max(delay, 0.1), nil, function()
		retire(rock, 0.5)
		warning:Destroy()
		quake(center, radius)
		swell(center, 1, radius * 2, Color3.fromRGB(255, 110, 30), 0.15, 0.4)
		local flames = emitter(
			FIRE_TEXTURE,
			ColorSequence.new(Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 50, 20)),
			NumberSequence.new(4, 0),
			radius * 2,
			0.7
		)
		flames.LightEmission = 1
		flames.Parent = anchorAt(center, 1.5)
		flames:Emit(40)
		flash(center, Color3.fromRGB(255, 120, 40), radius * 3, 7, 0.6)
	end)
end

-- Haz volcánico: rayo de lava del bastón (o la mano) del mago al enemigo mientras dure el atributo
-- "LavaBeamUntil" del personaje (el servidor lo quita antes si se corta). Núcleo amarillo, halo naranja,
-- chispas donde da y una luz que tiembla.
local function lavaBeam(character: Model?, target: Model?, seconds: number)
	if not (character and target) then
		return
	end
	local core = piece("Beam", Vector3.new(0.4, 0.4, 1), Color3.fromRGB(255, 230, 120))
	local glowPart = piece("BeamGlow", Vector3.new(1.4, 1.4, 1), Color3.fromRGB(255, 100, 20), nil, 0.5)
	core.Parent = folder
	glowPart.Parent = folder
	local impact = anchorAt(Vector3.zero, seconds + 1)
	local sparks = emitter(
		FIRE_TEXTURE,
		ColorSequence.new(Color3.fromRGB(255, 220, 100), Color3.fromRGB(255, 60, 10)),
		NumberSequence.new(1.2, 0),
		10,
		0.4
	)
	sparks.LightEmission = 1
	sparks.Rate = 40
	sparks.Parent = impact
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 40)
	light.Range = 14
	light.Parent = impact
	local function source(): Vector3?
		local tool = character:FindFirstChildOfClass("Tool")
		local handle = if tool then tool:FindFirstChild("Handle") else nil
		if handle and handle:IsA("BasePart") then
			return handle.Position + handle.CFrame.UpVector * 1.5
		end
		local hand = character:FindFirstChild("RightHand")
		return if hand and hand:IsA("BasePart") then hand.Position else nil
	end
	animate(seconds + 0.2, function(alpha)
		local untilTime = character:GetAttribute("LavaBeamUntil")
		local from = source()
		local to = rootOf(target)
		local active = typeof(untilTime) == "number" and Workspace:GetServerTimeNow() < untilTime
		if not (active and from and to) then
			core.Transparency = 1
			glowPart.Transparency = 1
			sparks.Enabled = false
			light.Enabled = false
			return
		end
		local length = (to.Position - from).Magnitude
		local cframe = CFrame.lookAt(from, to.Position) * CFrame.new(0, 0, -length / 2)
		local wobble = 1 + 0.15 * math.sin(alpha * 60)
		core.CFrame = cframe
		core.Size = Vector3.new(0.4 * wobble, 0.4 * wobble, length)
		glowPart.CFrame = cframe
		glowPart.Size = Vector3.new(1.4 * wobble, 1.4 * wobble, length)
		impact.WorldPosition = to.Position
		light.Brightness = 3 + 2 * math.sin(alpha * 40)
	end, function()
		fadeAway({ core, glowPart }, 0.2)
		sparks.Enabled = false
	end)
end

-- ===================================== Médico =====================================

-- Hojas que salen girando en círculo desde "center" hasta "radius".
local function leafWave(ground: Vector3, radius: number, count: number, height: number, seconds: number, twist: number)
	local leaves: { BasePart } = {}
	local spins: { Vector3 } = {}
	for index = 1, count do
		local part = leaf(rng:NextNumber(0.9, 1.3))
		part.CFrame = CFrame.new(ground)
		part.Parent = folder
		leaves[index] = part
		spins[index] = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-4, 4), rng:NextNumber(-8, 8))
	end
	animate(seconds, function(alpha)
		local eased = 1 - (1 - alpha) ^ 2
		local distance = 0.8 + (radius - 0.8) * eased
		for index, part in leaves do
			local angle = index / count * 2 * math.pi + twist + eased * 1.6
			local spin = spins[index] * alpha
			local position = ground
				+ Vector3.new(
					math.cos(angle) * distance,
					height + math.sin(alpha * math.pi) * 1.2,
					math.sin(angle) * distance
				)
			part.CFrame = CFrame.new(position) * CFrame.Angles(spin.X, -angle + spin.Y, spin.Z)
			part.Transparency = if alpha > 0.65 then (alpha - 0.65) / 0.35 else 0
		end
	end, function()
		for _, part in leaves do
			part:Destroy()
		end
	end)
end

-- Ungüento en área: dos coronas de hojas verdes que salen girando y una onda verde.
local function areaHeal(center: Vector3, radius: number)
	local ground = groundAt(center, groundParams())
	leafWave(ground, radius, 16, 1, 1.1, 0)
	task.delay(0.15, leafWave, ground, radius * 0.8, 12, 2.2, 1, 0.3)
	ring(ground + Vector3.new(0, 0.2, 0), 1, radius, 0.9, Color3.fromRGB(120, 240, 140), 0.5, 0.4)
	burst(center, SPARKLE_TEXTURE, Color3.fromRGB(150, 255, 160), 20, 0.8, 8, 0.8)
end

-- Curación en un aliado (dardo): hojitas y chispas verdes.
local function healBurst(position: Vector3)
	leafWave(position - Vector3.new(0, 2, 0), 3, 7, 1.5, 0.6, rng:NextNumber(0, 6))
	burst(position, SPARKLE_TEXTURE, Color3.fromRGB(150, 255, 160), 12, 0.7, 6, 0.6)
end

-- Resurgir: columna de luz verde que sube del médico, tres coronas de hojas que se abren hasta el radio
-- y una onda verde.
local function resurgence(center: Vector3, radius: number)
	local ground = groundAt(center, groundParams())
	local column = piece("Column", Vector3.new(radius * 0.3, 1, radius * 0.3), Color3.fromRGB(150, 255, 170), nil, 0.35)
	column.Shape = Enum.PartType.Cylinder
	column.Parent = folder
	animate(0.8, function(alpha)
		local height = 4 + 22 * alpha
		column.Size = Vector3.new(height, radius * 0.3 * (1 - 0.5 * alpha), radius * 0.3 * (1 - 0.5 * alpha))
		column.CFrame = CFrame.new(ground + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		column.Transparency = 0.35 + 0.65 * alpha
	end, function()
		column:Destroy()
	end)
	leafWave(ground, radius, 18, 1, 1.2, 0)
	task.delay(0.12, leafWave, ground, radius * 0.85, 14, 2.4, 1.1, 0.4)
	task.delay(0.24, leafWave, ground, radius * 0.7, 10, 3.8, 1, 0.8)
	ring(ground + Vector3.new(0, 0.2, 0), 1, radius, 0.9, Color3.fromRGB(120, 240, 140), 0.7, 0.3)
	swell(center, 2, radius * 1.2, Color3.fromRGB(150, 255, 170), 0.6, 0.6)
	burst(center, SPARKLE_TEXTURE, Color3.fromRGB(220, 255, 220), 30, 1, 14, 0.9)
	flash(center, Color3.fromRGB(150, 255, 170), radius * 2, 4, 0.6)
end

-- Dardo curativo: dardo amarillo con plumas y cola rojas.
local function healingDartLook(): Look
	local body = piece("Dart", Vector3.new(0.12, 0.12, 1.1), Color3.fromRGB(255, 215, 40))
	weld(
		body,
		piece("Tip", Vector3.new(0.05, 0.05, 0.45), Color3.fromRGB(230, 230, 235), Enum.Material.Metal),
		CFrame.new(0, 0, -0.75)
	)
	local red = Color3.fromRGB(230, 40, 35)
	weld(body, piece("Feather", Vector3.new(0.3, 0.03, 0.4), red), CFrame.new(0, 0, 0.5))
	weld(body, piece("Feather", Vector3.new(0.03, 0.3, 0.4), red), CFrame.new(0, 0, 0.5))
	trail(
		body,
		Vector3.new(0, 0, 0.55),
		ColorSequence.new(Color3.fromRGB(255, 50, 35), Color3.fromRGB(170, 0, 0)),
		0.3,
		0.3
	)
	return {
		body = body,
		land = function(position)
			retire(body, 0.4)
			burst(position, SPARKLE_TEXTURE, Color3.fromRGB(255, 225, 80), 6, 0.5, 5, 0.3)
		end,
	}
end

-- Destello amarillo: luz, chispas y una estrella de brillo que gira y se apaga.
local function glare(position: Vector3, size: number)
	local yellow = Color3.fromRGB(255, 220, 70)
	flash(position, yellow, size * 3, 5, 0.6)
	swell(position, size * 0.5, size * 1.3, yellow, 0.4, 0.35)
	burst(position, SPARKLE_TEXTURE, yellow, 18, 0.9, 10, 0.6)

	local anchor = anchorAt(position + Vector3.new(-size * 0.25, size * 0.3, 0), 0.8)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ShieldGlare"
	gui.Adornee = anchor
	gui.LightInfluence = 0
	gui.Size = UDim2.fromScale(0.1, 0.1)
	gui.Parent = folder
	Debris:AddItem(gui, 0.8)
	local star = Instance.new("Frame")
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Position = UDim2.fromScale(0.5, 0.5)
	star.Size = UDim2.fromScale(1, 1)
	star.BackgroundTransparency = 1
	star.Parent = gui
	local fade = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	for _, spec in
		{
			{ rotation = 0, length = 1 },
			{ rotation = 90, length = 1 },
			{ rotation = 45, length = 0.5 },
			{ rotation = -45, length = 0.5 },
		}
	do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromScale(spec.length, 0.06)
		ray.Rotation = spec.rotation
		ray.BackgroundColor3 = Color3.fromRGB(255, 245, 170)
		ray.BorderSizePixel = 0
		ray.Parent = star
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = fade
		gradient.Parent = ray
	end
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(0.18, 0.18)
	core.BackgroundColor3 = Color3.fromRGB(255, 255, 220)
	core.Parent = star
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = core
	TweenService
		:Create(gui, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromScale(size * 1.2, size * 1.2) })
		:Play()
	TweenService:Create(star, TweenInfo.new(0.7), { Rotation = 90 }):Play()
	task.delay(0.35, function()
		TweenService:Create(gui, TweenInfo.new(0.35), { Size = UDim2.fromScale(0.1, 0.1) }):Play()
	end)
end

local SHIELD_SIZE = 7.5

-- Burbuja verde del escudo de hojas alrededor de un personaje, con hojas que giran. Devuelve la función
-- que la quita ("broken": estalla en vez de apagarse).
local function startShield(character: Model): ((broken: boolean) -> ())?
	local root = rootOf(character)
	if not root then
		return nil
	end
	local bubble = ball("LeafShield", SHIELD_SIZE * 0.3, Color3.fromRGB(110, 230, 100), Enum.Material.ForceField)
	bubble.Position = root.Position
	bubble.Parent = folder
	local tint = ball("LeafShieldTint", SHIELD_SIZE * 0.3, Color3.fromRGB(120, 255, 120), Enum.Material.Neon, 0.92)
	tint.Position = root.Position
	tint.Parent = folder
	local grow = TweenInfo.new(0.3, Enum.EasingStyle.Back)
	TweenService:Create(bubble, grow, { Size = Vector3.one * SHIELD_SIZE }):Play()
	TweenService:Create(tint, grow, { Size = Vector3.one * (SHIELD_SIZE - 0.2) }):Play()
	local leaves: { BasePart } = {}
	for index = 1, 5 do
		local part = leaf(1.1)
		part.Parent = folder
		leaves[index] = part
	end

	local elapsed = 0
	local nextGlint = 2.5
	local connection = RunService.RenderStepped:Connect(function(deltaTime)
		elapsed += deltaTime
		if not root.Parent then
			return
		end
		bubble.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, elapsed * 0.6, 0)
		tint.CFrame = bubble.CFrame
		for index, part in leaves do
			local angle = elapsed * 1.8 + index / #leaves * 2 * math.pi
			local height = math.sin(elapsed * 1.3 + index) * 1.6
			local position = root.Position
				+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * (SHIELD_SIZE / 2)
				+ Vector3.new(0, height, 0)
			part.CFrame = CFrame.new(position) * CFrame.Angles(0.4, -angle, 0.3)
		end
		-- De vez en cuando, un brillo amarillo recorre la burbuja.
		if elapsed >= nextGlint then
			nextGlint += 2.5
			swell(root.Position, SHIELD_SIZE * 0.95, SHIELD_SIZE * 1.05, Color3.fromRGB(255, 225, 90), 0.75, 0.4)
		end
	end)

	return function(broken: boolean)
		connection:Disconnect()
		local seconds = if broken then 0.25 else 0.5
		local info = TweenInfo.new(seconds)
		local size = Vector3.one * SHIELD_SIZE * (if broken then 1.25 else 1)
		TweenService:Create(bubble, info, { Size = size, Transparency = 1 }):Play()
		TweenService:Create(tint, info, { Size = size, Transparency = 1 }):Play()
		Debris:AddItem(bubble, seconds)
		Debris:AddItem(tint, seconds)
		for _, part in leaves do
			if broken then
				local outward = part.Position - bubble.Position
				outward = if outward.Magnitude > 0.01 then outward.Unit else Vector3.xAxis
				fling(part, outward * 12 + Vector3.new(0, 8, 0), Vector3.new(4, 4, 4), 0.9)
			else
				fadeAway({ part }, 0.5)
			end
		end
		if broken then
			burst(bubble.Position, SPARKLE_TEXTURE, Color3.fromRGB(140, 255, 130), 16, 0.8, 12, 0.5)
		end
	end
end

-- Pone y quita la burbuja del escudo según los atributos del jugador (los pone AbilityService y los
-- gasta CombatService al absorber daño).
local function watchShields()
	type Shield = { character: Model, stop: (broken: boolean) -> () }
	local shields: { [Player]: Shield } = {}
	while true do
		local now = Workspace:GetServerTimeNow()
		for _, player in Players:GetPlayers() do
			local untilTime = player:GetAttribute("ShieldUntil")
			local health = player:GetAttribute("ShieldHealth")
			local expired = not (typeof(untilTime) == "number" and now < untilTime)
			local broken = not (typeof(health) == "number" and health > 0)
			local character = player.Character
			local shield = shields[player]
			if shield and (expired or broken or shield.character ~= character) then
				shield.stop(broken and not expired)
				shields[player] = nil
				shield = nil
			end
			if not shield and not expired and not broken and character then
				local stop = startShield(character)
				if stop then
					shields[player] = { character = character, stop = stop }
				end
			end
		end
		for player, shield in shields do
			if not player.Parent then
				shield.stop(false)
				shields[player] = nil
			end
		end
		task.wait(0.1)
	end
end

-- Escudo de hojas: el destello amarillo al ponerlo (la burbuja sale de watchShields).
local function shieldGlare(character: Model?)
	local root = rootOf(character)
	if root then
		glare(root.Position + Vector3.new(0, 0.5, 0), SHIELD_SIZE)
	end
end

-- Colores del tótem: madera y la pintura de los motivos navajos (turquesa, rojo, negro, blanco y ocre).
local WOOD_DARK = Color3.fromRGB(92, 58, 32)
local WOOD = Color3.fromRGB(128, 84, 46)
local WOOD_LIGHT = Color3.fromRGB(156, 108, 62)
local TURQUOISE = Color3.fromRGB(48, 178, 168)
local PAINT_RED = Color3.fromRGB(178, 48, 38)
local PAINT_BLACK = Color3.fromRGB(25, 22, 20)
local PAINT_WHITE = Color3.fromRGB(240, 232, 214)
local OCHRE = Color3.fromRGB(214, 160, 60)
local GEM_HEIGHT = 6.9

-- Tótem sanador: suelo verde con hojas y, en medio, un tótem de madera tallada al estilo navajo (tres
-- caras, alas de pájaro del trueno pintadas) con una gema verde brillante arriba. Sale del suelo, cura
-- con una onda verde cada segundo y se desvanece al acabar.
local function totem(position: Vector3, facing: Vector3, radius: number, seconds: number)
	local params = groundParams()
	local ground = groundAt(position, params)
	local look = Vector3.new(facing.X, 0, facing.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
	-- La cara del tótem (-Z) mira hacia la cámara del médico, que está detrás de él.
	local base = CFrame.lookAt(ground, ground - look)

	-- Suelo: césped verde con un borde que brilla y hojas caídas.
	local floor: { BasePart } = {}
	local rim =
		disc(ground + Vector3.new(0, 0.05, 0), radius + 0.4, Color3.fromRGB(110, 255, 120), Enum.Material.Neon, 0.5)
	local grass = disc(ground + Vector3.new(0, 0.1, 0), radius, Color3.fromRGB(80, 170, 70), Enum.Material.Grass, 0.25)
	table.insert(floor, rim)
	table.insert(floor, grass)
	for _ = 1, 40 do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local distance = math.sqrt(rng:NextNumber()) * (radius - 0.5)
		local part = leaf(rng:NextNumber(0.7, 1.2))
		part.CFrame = CFrame.new(ground + Vector3.new(math.cos(angle) * distance, 0.2, math.sin(angle) * distance))
			* CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 2 * math.pi), rng:NextNumber(-0.15, 0.15))
		table.insert(floor, part)
	end
	for _, part in floor do
		local target = part.Transparency
		part.Transparency = 1
		part.Parent = folder
		TweenService:Create(part, TweenInfo.new(0.5), { Transparency = target }):Play()
	end
	-- Chispas verdes que suben por toda la zona.
	local field = piece("TotemField", Vector3.new(radius * 1.4, 0.1, radius * 1.4), Color3.new(), nil, 1)
	field.CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0))
	field.Parent = folder
	local sparkles =
		emitter(SPARKLE_TEXTURE, ColorSequence.new(Color3.fromRGB(140, 255, 150)), NumberSequence.new(0.4, 0), 2, 2.5)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.SpreadAngle = Vector2.new(10, 10)
	sparkles.Drag = 0
	sparkles.LightEmission = 1
	sparkles.Rate = 14
	sparkles.Parent = field
	table.insert(floor, field)

	-- El tótem, pieza a pieza (cada una con su sitio relativo a la base).
	type Carved = { part: BasePart, offset: CFrame }
	local carved: { Carved } = {}
	local function add(
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	): Part
		local part = piece("Totem", size, color, material or Enum.Material.SmoothPlastic)
		if shape then
			part.Shape = shape
			part.Size = size
		end
		part.CastShadow = true
		part.Parent = folder
		table.insert(carved, { part = part, offset = offset })
		return part
	end
	local function wood(size: Vector3, y: number, color: Color3)
		add(size, CFrame.new(0, y, 0), color, Enum.Material.Wood)
	end
	local function band(width: number, y: number, color: Color3)
		add(Vector3.new(width, 0.2, width), CFrame.new(0, y, 0), color)
	end
	-- Rombo pintado sobre una cara: "z" es la distancia a la que está la cara.
	local function diamond(size: number, x: number, y: number, z: number, color: Color3)
		add(Vector3.new(size, size, 0.06), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(45)), color)
	end
	local function sideDiamonds(y: number, half: number)
		for _, side in { -1, 1 } do
			local x = side * (half + 0.03)
			add(Vector3.new(0.06, 0.5, 0.5), CFrame.new(x, y, 0) * CFrame.Angles(math.rad(45), 0, 0), TURQUOISE)
			add(
				Vector3.new(0.08, 0.24, 0.24),
				CFrame.new(x + side * 0.01, y, 0) * CFrame.Angles(math.rad(45), 0, 0),
				PAINT_BLACK
			)
		end
	end

	-- Peana.
	add(Vector3.new(2.6, 0.6, 2.6), CFrame.new(0, 0.3, 0), WOOD_DARK, Enum.Material.WoodPlanks)

	-- Primera cara (abajo): ojos grandes, cejas y boca con dientes.
	wood(Vector3.new(1.7, 1.9, 1.7), 1.55, WOOD)
	band(1.78, 0.72, TURQUOISE)
	band(1.78, 2.4, PAINT_RED)
	local front = -0.88
	for _, side in { -1, 1 } do
		add(Vector3.new(0.42, 0.26, 0.06), CFrame.new(side * 0.4, 1.85, front), PAINT_WHITE)
		add(Vector3.new(0.18, 0.18, 0.08), CFrame.new(side * 0.4, 1.85, front - 0.02), PAINT_BLACK)
		add(
			Vector3.new(0.55, 0.1, 0.06),
			CFrame.new(side * 0.42, 2.12, front) * CFrame.Angles(0, 0, side * math.rad(-12)),
			PAINT_BLACK
		)
	end
	add(Vector3.new(0.85, 0.24, 0.06), CFrame.new(0, 1.25, front), PAINT_RED)
	for index = -2, 1 do
		add(Vector3.new(0.12, 0.1, 0.08), CFrame.new(index * 0.18 + 0.09, 1.3, front - 0.02), PAINT_WHITE)
	end
	sideDiamonds(1.55, 0.85)

	-- Segunda cara: ojos en rombo, nariz tallada, rayas rojas en las mejillas y franja de rombos.
	wood(Vector3.new(1.6, 1.7, 1.6), 3.35, WOOD_LIGHT)
	band(1.68, 2.58, PAINT_BLACK)
	front = -0.83
	for _, side in { -1, 1 } do
		diamond(0.45, side * 0.38, 3.65, front, PAINT_WHITE)
		diamond(0.22, side * 0.38, 3.65, front - 0.02, PAINT_BLACK)
		for stripe = 0, 2 do
			add(Vector3.new(0.08, 0.4, 0.06), CFrame.new(side * (0.5 + stripe * 0.12), 3.15, front), PAINT_RED)
		end
	end
	add(Vector3.new(0.35, 0.5, 0.4), CFrame.new(0, 3.3, front - 0.15), OCHRE, Enum.Material.Wood, Enum.PartType.Wedge)
	add(Vector3.new(0.7, 0.12, 0.06), CFrame.new(0, 2.85, front), PAINT_BLACK)
	for index = -2, 2 do
		diamond(0.2, index * 0.3, 4.05, front, if index % 2 == 0 then PAINT_RED else PAINT_BLACK)
	end
	sideDiamonds(3.35, 0.8)

	-- Alas del pájaro del trueno, con plumas pintadas.
	local feathers = { TURQUOISE, PAINT_RED, PAINT_BLACK, PAINT_WHITE }
	for _, side in { -1, 1 } do
		local wing = CFrame.new(side * 0.75, 4.75, 0)
			* CFrame.Angles(0, 0, side * math.rad(18))
			* CFrame.new(side * 1.3, 0, 0)
		add(Vector3.new(2.6, 0.95, 0.22), wing, WOOD, Enum.Material.Wood)
		for index, color in feathers do
			add(Vector3.new(0.38, 0.97, 0.26), wing * CFrame.new(side * (-0.9 + index * 0.55 - 0.55), 0, 0), color)
		end
	end

	-- Cabeza del pájaro: ojos redondos y pico.
	wood(Vector3.new(1.5, 1.6, 1.5), 5, WOOD)
	band(1.58, 4.28, TURQUOISE)
	band(1.58, 5.72, TURQUOISE)
	front = -0.77
	for _, side in { -1, 1 } do
		add(
			Vector3.new(0.06, 0.5, 0.5),
			CFrame.new(side * 0.36, 5.25, front) * CFrame.Angles(0, math.rad(90), 0),
			PAINT_WHITE,
			nil,
			Enum.PartType.Cylinder
		)
		add(
			Vector3.new(0.08, 0.24, 0.24),
			CFrame.new(side * 0.36, 5.25, front - 0.02) * CFrame.Angles(0, math.rad(90), 0),
			PAINT_BLACK,
			nil,
			Enum.PartType.Cylinder
		)
	end
	add(Vector3.new(0.5, 0.45, 0.9), CFrame.new(0, 4.85, front - 0.45), OCHRE, Enum.Material.Wood, Enum.PartType.Wedge)

	-- Remate y engaste de la gema.
	add(Vector3.new(1.9, 0.25, 1.9), CFrame.new(0, 5.95, 0), WOOD_DARK, Enum.Material.Wood)
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		local tilt = CFrame.Angles(corner.Z * math.rad(15), 0, -corner.X * math.rad(15))
		add(
			Vector3.new(0.18, 0.75, 0.18),
			CFrame.new(corner.X * 0.45, 6.4, corner.Z * 0.45) * tilt,
			WOOD_DARK,
			Enum.Material.Wood
		)
	end

	-- Gema verde brillante (gira y flota un poco).
	local gemShape = CFrame.Angles(math.rad(45), 0, math.rad(35.26))
	local gem = piece("Gem", Vector3.one * 0.85, Color3.fromRGB(60, 255, 110))
	gem.Parent = folder
	local shell = piece("GemShell", Vector3.one * 1.05, Color3.fromRGB(150, 255, 170), Enum.Material.Glass, 0.6)
	shell.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = gem.Color
	light.Range = radius * 0.75
	light.Brightness = 2.5
	light.Parent = gem
	local glitter = emitter(SPARKLE_TEXTURE, ColorSequence.new(gem.Color), NumberSequence.new(0.5, 0), 2, 1)
	glitter.LightEmission = 1
	glitter.Rate = 6
	glitter.Parent = gem

	-- Hojas que suben girando alrededor del tótem.
	local floating: { BasePart } = {}
	for index = 1, 8 do
		local part = leaf(0.9)
		part.Parent = folder
		floating[index] = part
	end

	local elapsed = 0
	local nextPulse = 1
	animate(seconds, function(_, deltaTime)
		elapsed += deltaTime
		local rise = math.min(elapsed / 0.6, 1)
		local lift = CFrame.new(0, -8 * (1 - rise) ^ 2, 0)
		for _, item in carved do
			item.part.CFrame = base * lift * item.offset
		end
		local gemFrame = base
			* lift
			* CFrame.new(0, GEM_HEIGHT + math.sin(elapsed * 2) * 0.15, 0)
			* CFrame.Angles(0, elapsed * 1.5, 0)
			* gemShape
		gem.CFrame = gemFrame
		shell.CFrame = gemFrame
		for index, part in floating do
			local climb = (elapsed * 0.8 + index / #floating * 6) % 6
			local angle = elapsed * 0.9 + index / #floating * 2 * math.pi
			local distance = 2.5 + math.sin(elapsed + index) * 0.6
			part.CFrame = CFrame.new(
				ground + Vector3.new(math.cos(angle) * distance, 0.3 + climb, math.sin(angle) * distance)
			) * CFrame.Angles(math.sin(elapsed * 3 + index) * 0.6, -angle, 0.4)
			part.Transparency = math.clamp((climb - 4.5) / 1.5, 0, 1)
		end
		-- Cada segundo cura: la gema brilla y una onda verde recorre el suelo.
		if elapsed >= nextPulse then
			nextPulse += 1
			ring(ground + Vector3.new(0, 0.3, 0), 1, radius, 0.8, Color3.fromRGB(130, 255, 140), 0.4, 0.45)
			swell(gem.Position, 1, 3, Color3.fromRGB(120, 255, 140), 0.4, 0.4)
		end
	end, function()
		local parts: { BasePart } = { gem, shell }
		for _, item in carved do
			table.insert(parts, item.part)
		end
		for _, part in floating do
			table.insert(parts, part)
		end
		for _, part in floor do
			table.insert(parts, part)
		end
		sparkles.Enabled = false
		glitter.Enabled = false
		TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
		burst(gem.Position, SPARKLE_TEXTURE, gem.Color, 20, 0.8, 8, 0.6)
		fadeAway(parts, 0.6)
	end)
end

-- Polvo somnífero: un puñado de polvo lila vuela hasta el punto y suelta la nube (la que se queda es una
-- zona, "Zone" "Cloud").
local function sleepPowder(origin: Vector3, center: Vector3, radius: number)
	local lilac = Color3.fromRGB(205, 150, 255)
	local pouch = ball("Powder", 0.7, lilac)
	trail(pouch, Vector3.zero, ColorSequence.new(Color3.fromRGB(240, 210, 255), lilac), 0.4, 0.5)
	local landing = center + Vector3.new(0, 1, 0)
	fly(pouch, origin, landing, (landing - origin).Magnitude / 0.5, nil, function()
		retire(pouch, 0.4)
		ring(center + Vector3.new(0, 0.3, 0), 1, radius, 0.5, lilac, 0.6, 0.3)
		burst(landing, SPARKLE_TEXTURE, Color3.fromRGB(255, 220, 255), 20, 1, radius, 0.8)
	end)
end

-- Dormido: "💤" que sube y baja sobre la cabeza del mono mientras duerme.
local function asleep(model: Model?, seconds: number)
	local root = rootOf(model)
	if not (model and root) then
		return
	end
	local head = model:FindFirstChild("Head")
	local adornee = if head and head:IsA("BasePart") then head else root
	local gui = Instance.new("BillboardGui")
	gui.Name = "Asleep"
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Size = UDim2.fromOffset(40, 40)
	gui.StudsOffset = Vector3.new(0.8, adornee.Size.Y / 2 + 1.4, 0)
	gui.Parent = folder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Text = "💤"
	label.Parent = gui
	-- Remate de "Nana de la selva" (Combat/Status.expose): cuánto daño más recibe mientras duerme.
	local exposedUntil = model:GetAttribute("ExposedUntil")
	local bonus = model:GetAttribute("ExposedBonus")
	if
		typeof(exposedUntil) == "number"
		and Workspace:GetServerTimeNow() < exposedUntil
		and typeof(bonus) == "number"
	then
		gui.Size = UDim2.fromOffset(56, 58)
		label.Size = UDim2.fromScale(1, 0.7)
		local extra = Instance.new("TextLabel")
		extra.BackgroundTransparency = 1
		extra.Position = UDim2.fromScale(0, 0.68)
		extra.Size = UDim2.fromScale(1, 0.32)
		extra.Font = Enum.Font.BuilderSansBold
		extra.TextScaled = true
		extra.TextColor3 = Color3.fromRGB(255, 150, 60)
		extra.TextStrokeTransparency = 0.3
		extra.Text = `+{math.round(bonus * 100)} %`
		extra.Parent = gui
	end
	local bob = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(gui, bob, { StudsOffset = gui.StudsOffset + Vector3.new(0, 0.6, 0) }):Play()
	Debris:AddItem(gui, seconds)
end

-- Vapor morado que sube de los monos envenenados mientras dura el atributo "PoisonedUntil" (lo pone
-- Combat/Status.poison).
local function watchPoison()
	local fumes: { [Model]: Attachment } = {}
	while true do
		local now = Workspace:GetServerTimeNow()
		for _, enemy in CollectionService:GetTagged(Config.Combat.EnemyTag) do
			if enemy:IsA("Model") then
				local untilTime = enemy:GetAttribute("PoisonedUntil")
				local poisoned = typeof(untilTime) == "number" and now < untilTime
				local current = fumes[enemy]
				local root = rootOf(enemy)
				if poisoned and not current and root then
					-- Desde lo alto del cuerpo: desde el centro, el propio cuerpo lo tapa.
					local attachment = Instance.new("Attachment")
					attachment.Name = "PoisonFumes"
					attachment.Position = Vector3.new(0, root.Size.Y / 2 + 0.3, 0)
					attachment.Parent = root
					local vapor = emitter(
						SMOKE_TEXTURE,
						ColorSequence.new(Color3.fromRGB(155, 70, 255), Color3.fromRGB(100, 40, 190)),
						NumberSequence.new(1, 2.6),
						3,
						1.4
					)
					vapor.EmissionDirection = Enum.NormalId.Top
					vapor.SpreadAngle = Vector2.new(50, 50)
					vapor.Acceleration = Vector3.new(0, 3, 0)
					-- Casi opaco al salir: sobre la arena, un humo claro no se ve.
					vapor.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.05),
						NumberSequenceKeypoint.new(0.5, 0.35),
						NumberSequenceKeypoint.new(1, 1),
					})
					vapor.LightEmission = 0.15
					vapor.Drag = 1.5
					vapor.Rate = 12
					vapor.Parent = attachment
					local drops = emitter(
						SPARKLE_TEXTURE,
						ColorSequence.new(Color3.fromRGB(185, 120, 255)),
						NumberSequence.new(0.6, 0),
						3,
						0.8
					)
					drops.LightEmission = 1
					drops.Rate = 6
					drops.Parent = attachment
					fumes[enemy] = attachment
				elseif not poisoned and current then
					current:Destroy()
					fumes[enemy] = nil
				end
			end
		end
		for enemy, attachment in fumes do
			if not enemy.Parent then
				attachment:Destroy()
				fumes[enemy] = nil
			end
		end
		task.wait(0.2)
	end
end

-- ===================================== Combos =====================================

-- La Bola de fuego que cierra el combo del mago rompe el hielo: esquirlas, destellos y vapor.
local function iceShatter(position: Vector3)
	for _ = 1, 14 do
		local shard = piece(
			"IceShard",
			Vector3.one * rng:NextNumber(0.3, 0.8),
			Color3.fromRGB(190, 230, 255),
			Enum.Material.Ice,
			0.15
		)
		shard.CFrame =
			CFrame.new(position + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 2), rng:NextNumber(-1, 1)))
		fling(
			shard,
			Vector3.new(rng:NextNumber(-16, 16), rng:NextNumber(12, 26), rng:NextNumber(-16, 16)),
			Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8)),
			0.9
		)
	end
	burst(position, SPARKLE_TEXTURE, Color3.fromRGB(210, 240, 255), 20, 1, 12, 0.6)
	burst(position, SMOKE_TEXTURE, Color3.fromRGB(235, 245, 255), 8, 2.5, 4, 0.9)
	flash(position, Color3.fromRGB(170, 220, 255), 16, 4, 0.4)
end

-- ¡Combo completo!: aro dorado a los pies y chispas; más grande cuanto mayor es la racha.
local function comboComplete(character: Model?, streak: number?)
	local root = rootOf(character)
	if not root then
		return
	end
	local level = math.clamp(if typeof(streak) == "number" then streak else 1, 1, 5)
	local gold = Color3.fromRGB(255, 205, 70)
	local feet = root.Position - Vector3.new(0, 2.8, 0)
	ring(feet, 1, 6 + level * 2, 0.6, gold, 0.5, 0.2)
	burst(root.Position, SPARKLE_TEXTURE, gold, 14 + level * 6, 1, 10 + level * 2, 0.6)
	flash(root.Position, gold, 14, 3 + level, 0.5)
end

-- Contorno de color sobre "character" que se apaga en "seconds".
local function glow(character: Model, color: Color3, seconds: number)
	local highlight = Instance.new("Highlight")
	highlight.Name = "GuardGlow"
	highlight.FillColor = color
	highlight.FillTransparency = 0.45
	highlight.OutlineColor = color
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
	TweenService:Create(highlight, TweenInfo.new(seconds), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	Debris:AddItem(highlight, seconds + 0.05)
end

-- Guardia (Fase 10, C5; Combat/Guard), delante del pecho:
--   - "Block": chispa blanca pequeña.
--   - "Parry": destello dorado en todo el cuerpo, aro dorado y chispas (el dorado es solo del parry).
--   - "Break": estallido naranja con esquirlas que caen y grietas oscuras en el aire (guardia rota).
local function guardFx(character: Model?, kind: string?)
	local root = rootOf(character)
	if not (character and root) then
		return
	end
	local front = root.Position + root.CFrame.LookVector * 1.5 + Vector3.new(0, 0.8, 0)
	-- La propia guardia (C12): un golpe seco al parar y uno más fuerte al romperse.
	if character == Players.LocalPlayer.Character then
		local settings = Config.CameraShake
		if kind == "Parry" then
			CameraShake.play(settings.ParryPower, settings.ParrySeconds)
		elseif kind == "Break" then
			CameraShake.play(settings.BreakPower, settings.BreakSeconds)
		end
	end
	if kind == "Parry" then
		local gold = Color3.fromRGB(255, 205, 60)
		glow(character, gold, 0.35)
		ring(root.Position + Vector3.new(0, 0.5, 0), 1.5, 7, 0.35, gold, 0.4, 0.1)
		burst(front, SPARKLE_TEXTURE, gold, 24, 1.2, 16, 0.4)
		flash(front, gold, 16, 4, 0.35)
	elseif kind == "Break" then
		local orange = Color3.fromRGB(255, 130, 40)
		glow(character, orange, 0.6)
		burst(front, SPARKLE_TEXTURE, orange, 18, 1, 12, 0.5)
		flash(front, orange, 12, 3, 0.4)
		-- Esquirlas: cubitos naranjas que saltan hacia fuera y caen.
		for _ = 1, 8 do
			local shard = piece("GuardShard", Vector3.one * rng:NextNumber(0.25, 0.45), orange, Enum.Material.Neon)
			shard.CFrame = CFrame.new(front)
			shard.Parent = folder
			local velocity = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.4, 1.2), rng:NextNumber(-1, 1)) * 14
			local start = front
			animate(0.6, function(alpha)
				local t = alpha * 0.6
				shard.CFrame = CFrame.new(start + velocity * t + GRAVITY * 0.5 * t * t) * CFrame.Angles(t * 9, t * 7, 0)
				shard.Transparency = alpha
			end, function()
				shard:Destroy()
			end)
		end
		-- Grietas: rayas oscuras en estrella delante del pecho, mirando hacia fuera.
		local cracks: { BasePart } = {}
		for index = 1, 5 do
			local crack =
				piece("GuardCrack", Vector3.new(0.12, rng:NextNumber(1, 1.8), 0.05), Color3.fromRGB(60, 25, 5))
			crack.CFrame = CFrame.lookAt(front, front + root.CFrame.LookVector)
				* CFrame.Angles(0, 0, math.rad(index * 72 + rng:NextNumber(-15, 15)))
				* CFrame.new(0, crack.Size.Y / 2, 0)
			crack.Parent = folder
			table.insert(cracks, crack)
		end
		fadeAway(cracks, 0.3, 0.3)
	else
		burst(front, SPARKLE_TEXTURE, Color3.fromRGB(235, 240, 255), 8, 0.7, 10, 0.25)
	end
end

-- Evasivo (Fase 10, C7; Combat/Evasive): sale del aturdido o del agarre con una ráfaga de aire blanco y
-- azul donde estaba (sin dorado ni naranja, que son de la guardia) y un brillo azul en el cuerpo.
local function evasiveFx(character: Model?)
	local root = rootOf(character)
	if not (character and root) then
		return
	end
	local blue = Color3.fromRGB(150, 210, 255)
	local white = Color3.fromRGB(240, 248, 255)
	local feet = root.Position - Vector3.new(0, 2.5, 0)
	glow(character, blue, 0.4)
	swell(root.Position, 2, 7, white, 0.5, 0.3)
	ring(feet + Vector3.new(0, 0.3, 0), 1, 7, 0.35, blue, 0.35, 0.15)
	burst(root.Position, SMOKE_TEXTURE, white, 14, 2.5, 10, 0.5)
	burst(root.Position, SPARKLE_TEXTURE, blue, 16, 0.9, 14, 0.35)
end

-- Esquiva (Fase 15, V3; también la Embestida y el Evasivo en el propio cliente): estela fina blanco-azulada
-- pegada a la raíz que se apaga enseguida, bocanada de polvo claro en los pies hacia atrás y el sonido del
-- aire. Más discreta que el Evasivo (sin brillo, ni aro, ni destello). Sin la dirección, sale de la velocidad
-- horizontal de la raíz y, si está quieta, de -LookVector.
local function dodgeFx(character: Model?, direction: Vector3?)
	local root = rootOf(character)
	if not (character and root) then
		return
	end
	local flat = if direction then Vector3.new(direction.X, 0, direction.Z) else Vector3.zero
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	end
	if flat.Magnitude < 0.01 then
		flat = -Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	if flat.Magnitude < 0.01 then
		return
	end
	flat = flat.Unit
	local streak = trail(root, Vector3.new(0, 0.3, 0), ColorSequence.new(Color3.fromRGB(215, 232, 250)), 0.35, 0.8)
	streak.LightEmission = 0.35
	streak.Transparency = NumberSequence.new(0.45, 1)
	Debris:AddItem(streak, 0.8)
	if streak.Attachment0 then
		Debris:AddItem(streak.Attachment0, 0.8)
	end
	if streak.Attachment1 then
		Debris:AddItem(streak.Attachment1, 0.8)
	end
	-- Sigue unos instantes (lo que dura el empuje) y deja de dibujar: la estela se desvanece sola.
	task.delay(0.35, function()
		streak.Enabled = false
	end)
	local feet = root.Position - Vector3.new(0, 2.5, 0) - flat * 1.2
	burst(feet, SMOKE_TEXTURE, Color3.fromRGB(205, 190, 165), 5, 1.4, 4, 0.5)
	Sfx.play("Dodge", root)
end

-- Amago (C8, Combat/Feint): bocanada corta de humo gris delante del pecho, donde iba a salir el golpe.
-- Pequeña y sin brillo para no confundirse con el Evasivo (blanco y azul, todo el cuerpo): solo dice
-- "lo ha cancelado", para que el rival aprenda a leerlo.
local function feintFx(character: Model?)
	local root = rootOf(character)
	if not (character and root) then
		return
	end
	local grey = Color3.fromRGB(165, 160, 155)
	local front = root.Position + root.CFrame.LookVector * 1.8 + Vector3.new(0, 0.6, 0)
	swell(front, 0.6, 2.6, grey, 0.55, 0.25, Enum.Material.SmoothPlastic)
	burst(front, SMOKE_TEXTURE, grey, 10, 1.8, 5, 0.45)
end

-- Icono sobre lo que marcó el primer paso de TU combo (atributos "ComboMarkBy"/"ComboMarkUntil",
-- ComboService): así ves a quién rematar. Los demás jugadores no lo ven.
local function watchComboMarks()
	local player = Players.LocalPlayer
	local icons: { [Instance]: BillboardGui } = {}
	local function check(target: Instance, now: number, icon: string)
		local untilTime = target:GetAttribute("ComboMarkUntil")
		local marked = target:GetAttribute("ComboMarkBy") == player.UserId
			and typeof(untilTime) == "number"
			and now < untilTime
		local gui = icons[target]
		if marked and not gui then
			local head = target:FindFirstChild("Head")
			local adornee = if head and head:IsA("BasePart") then head else rootOf(target)
			if adornee then
				local newGui = Instance.new("BillboardGui")
				newGui.Name = "ComboMark"
				newGui.Adornee = adornee
				newGui.AlwaysOnTop = true
				newGui.LightInfluence = 0
				newGui.MaxDistance = 200
				newGui.Size = UDim2.fromOffset(34, 34)
				newGui.StudsOffset = Vector3.new(0, adornee.Size.Y / 2 + 0.6, 0)
				newGui.SizeOffset = Vector2.new(0, -0.6)
				newGui.Parent = folder
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromScale(1, 1)
				label.TextScaled = true
				label.Text = icon
				label.Parent = newGui
				local scale = Instance.new("UIScale")
				scale.Scale = 2
				scale.Parent = label
				TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				icons[target] = newGui
			end
		elseif not marked and gui then
			gui:Destroy()
			icons[target] = nil
		elseif gui then
			-- Tras una conexión la marca pasa al otro combo: cambia su icono.
			local label = gui:FindFirstChildOfClass("TextLabel")
			if label and label.Text ~= icon then
				label.Text = icon
			end
		end
	end
	while true do
		local roleId = player:GetAttribute("Role")
		local combos = if typeof(roleId) == "string" then Combos[roleId] else nil
		local index = player:GetAttribute("ComboIndex")
		local combo = if combos then combos[if typeof(index) == "number" then index else 1] or combos[1] else nil
		local now = Workspace:GetServerTimeNow()
		if combo then
			for _, enemy in CollectionService:GetTagged(Config.Combat.EnemyTag) do
				check(enemy, now, combo.icon)
			end
			for _, other in Players:GetPlayers() do
				if other.Character then
					check(other.Character, now, combo.icon)
				end
			end
		end
		for target, gui in icons do
			if not target.Parent or not combo then
				gui:Destroy()
				icons[target] = nil
			end
		end
		task.wait(0.2)
	end
end

-- ===================================== Proyectiles (C9) =====================================

-- Lo que disparan las armas a distancia: piedra (honda), flecha (arco), dardo de savia (cerbatana) o
-- bola de energía (bastón). Al pararse, desaparece.
local function weaponLook(style: string): Look
	local body: Part
	if style == "Arrow" then
		body = piece("Projectile", Vector3.new(0.15, 0.15, 2.2), Color3.fromRGB(120, 85, 50), Enum.Material.Wood)
	elseif style == "Dart" then
		body = piece("Projectile", Vector3.new(0.1, 0.1, 0.9), Color3.fromRGB(150, 225, 120))
	elseif style == "Spell" then
		body = ball("Projectile", 0.9, Color3.fromRGB(170, 110, 255))
		local light = Instance.new("PointLight")
		light.Color = body.Color
		light.Range = 8
		light.Parent = body
	else
		body = ball("Projectile", 0.6, Color3.fromRGB(130, 130, 135), Enum.Material.SmoothPlastic)
	end
	return {
		body = body,
		land = function()
			body:Destroy()
		end,
	}
end

-- El remate de un arma (C9b): más grande, del color de su remate y con estela. El del bastón estalla
-- al pararse en el radio "splash" (lo que alcanza el servidor); el de la honda levanta polvo.
local function finisherLook(style: string, splash: number?): Look
	local color = FINISHER_COLORS[style] or FINISHER_COLORS.Stone
	local body: Part
	if style == "Arrow" then
		body = arrow(Color3.fromRGB(120, 85, 50), color, Color3.fromRGB(235, 250, 255), Enum.Material.Neon)
		body.Size = Vector3.new(0.22, 0.22, 2.8)
		trail(body, Vector3.new(0, 0, 1.2), ColorSequence.new(Color3.fromRGB(240, 252, 255), color), 0.45, 0.4)
	elseif style == "Dart" then
		body = piece("Projectile", Vector3.new(0.18, 0.18, 1.3), color)
		trail(body, Vector3.new(0, 0, 0.6), ColorSequence.new(Color3.fromRGB(200, 255, 200), color), 0.35, 0.3)
	elseif style == "Spell" then
		body = ball("Projectile", 1.5, color)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 12
		light.Brightness = 2
		light.Parent = body
		trail(body, Vector3.zero, ColorSequence.new(Color3.fromRGB(230, 240, 255), color), 0.3, 1.1)
	else
		body = ball("Projectile", 1.1, Color3.fromRGB(105, 100, 95), Enum.Material.Slate)
		trail(body, Vector3.zero, ColorSequence.new(color, Color3.fromRGB(150, 130, 100)), 0.3, 0.7)
	end
	return {
		body = body,
		land = function(position)
			retire(body, 0.5)
			if style == "Spell" then
				local radius = splash or 6
				swell(position, 1, radius * 2, color, 0.2, 0.3)
				swell(position, 1, radius, Color3.fromRGB(235, 245, 255), 0, 0.2)
				burst(position, SPARKLE_TEXTURE, color, 20, 1.2, radius * 2, 0.6)
				flash(position, color, radius * 3, 5, 0.4)
			elseif style == "Stone" then
				burst(position, SMOKE_TEXTURE, Color3.fromRGB(170, 150, 120), 10, 2, 6, 0.6)
			else
				burst(position, SPARKLE_TEXTURE, color, 10, 0.8, 8, 0.5)
			end
		end,
	}
end

-- ===================================== Laboratorio (Fase 13) =====================================

local LAB_DART = Color3.fromRGB(150, 215, 255)
local LAB_BANANA = Color3.fromRGB(255, 225, 60)
local LAB_NET = Color3.fromRGB(205, 190, 150)
local LAB_ACID = Color3.fromRGB(135, 55, 205) -- morado: veneno (sin neón, que lo vuelve rosa)

-- Los disparos de las armas del Laboratorio. La bola de suero estalla al pararse en "splash" (el área
-- del servidor) con salpicadura morada.
local function labLook(style: string, splash: number?): Look
	local body: Part
	if style == "LabDart" then
		body = piece("Projectile", Vector3.new(0.12, 0.12, 0.8), LAB_DART, Enum.Material.Neon)
		trail(body, Vector3.new(0, 0, 0.4), ColorSequence.new(Color3.new(1, 1, 1), LAB_DART), 0.12, 0.15)
	elseif style == "LabBanana" then
		body = piece("Projectile", Vector3.new(0.3, 0.3, 1.4), LAB_BANANA, Enum.Material.Neon)
		trail(body, Vector3.new(0, 0, 0.7), ColorSequence.new(Color3.fromRGB(255, 250, 200), LAB_BANANA), 0.3, 0.35)
		local light = Instance.new("PointLight")
		light.Color = LAB_BANANA
		light.Range = 8
		light.Parent = body
	elseif style == "LabNet" then
		-- Red cuadrada que vuela de cara, con un peso en cada esquina.
		body = piece("Projectile", Vector3.new(2.2, 2.2, 0.08), LAB_NET, Enum.Material.Fabric, 0.35)
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				local weight = piece("NetWeight", Vector3.one * 0.3, Color3.fromRGB(80, 80, 85), Enum.Material.Metal)
				weld(body, weight, CFrame.new(x * 1.1, y * 1.1, 0))
			end
		end
	else
		body = ball("Projectile", 1, LAB_ACID, Enum.Material.SmoothPlastic)
		local light = Instance.new("PointLight")
		light.Color = LAB_ACID
		light.Range = 8
		light.Parent = body
		trail(body, Vector3.zero, ColorSequence.new(LAB_ACID, Color3.fromRGB(110, 40, 150)), 0.25, 0.7)
	end
	return {
		body = body,
		land = function(position)
			retire(body, 0.3)
			if style == "LabAcid" then
				local radius = splash or 6
				swell(position, 1, radius * 2, LAB_ACID, 0.3, 0.3)
				burst(position, SMOKE_TEXTURE, LAB_ACID, 16, 2, radius * 1.5, 0.7)
			elseif style == "LabBanana" then
				burst(position, SPARKLE_TEXTURE, LAB_BANANA, 8, 0.6, 8, 0.4)
				-- Más peso: anillo amarillo y chispas gruesas.
				ring(position, 0.3, 2.2, 0.25, LAB_BANANA, 0.15, 0.1)
				burst(position, SPARKLE_TEXTURE, LAB_BANANA, 6, 1.1, 11, 0.35)
			elseif style == "LabDart" then
				-- Chispas cian cortas y un anillito que se abre rápido.
				burst(position, SPARKLE_TEXTURE, LAB_DART, 6, 0.35, 7, 0.2)
				ring(position, 0.1, 1, 0.15, LAB_DART, 0.08, 0.2)
			elseif style == "LabNet" then
				-- Bocanada beige de fibras y un disco-red que se abre y se desvanece.
				burst(position, SMOKE_TEXTURE, LAB_NET, 8, 0.9, 5, 0.3)
				local mesh = disc(position, 0.3, LAB_NET, Enum.Material.Fabric, 0.3)
				mesh.Parent = folder
				TweenService:Create(mesh, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(0.1, 3.4, 3.4),
					Transparency = 1,
				}):Play()
				Debris:AddItem(mesh, 0.35)
			end
		end,
	}
end

-- Charco de suero donde estalla el cañón (centro, radio, segundos): solo se ve, el veneno ya lo ha
-- puesto el servidor a los que estaban dentro.
local function acidPuddle(center: Vector3, radius: number, seconds: number)
	local ground = groundAt(center, groundParams())
	local puddle = disc(ground + Vector3.new(0, 0.05, 0), radius, LAB_ACID, Enum.Material.SmoothPlastic, 0.35)
	puddle.Parent = folder
	local bubbles = emitter(SMOKE_TEXTURE, ColorSequence.new(LAB_ACID), NumberSequence.new(0.6, 1.4), 1.2, 1.5)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Rate = 6
	local attachment = anchorAt(ground, seconds + 1.5)
	bubbles.Parent = attachment
	task.delay(seconds, function()
		bubbles.Enabled = false
		fadeAway({ puddle }, 0.6)
	end)
end

-- Red enredada en "model" mientras dura (segundos): un cuadro de cuerda alrededor de las piernas.
local function entangled(model: Model?, seconds: number)
	local root = rootOf(model)
	if not (model and root) then
		return
	end
	local net = piece("Entangled", Vector3.new(3, 2.6, 3), LAB_NET, Enum.Material.Fabric, 0.55)
	weld(root, net, CFrame.new(0, -1.6, 0))
	task.delay(seconds, function()
		fadeAway({ net }, 0.3)
	end)
end

local LOOKS: { [string]: (extra: { any }) -> Look } = {
	Stone = function()
		return weaponLook("Stone")
	end,
	Arrow = function()
		return weaponLook("Arrow")
	end,
	Dart = function()
		return weaponLook("Dart")
	end,
	Spell = function()
		return weaponLook("Spell")
	end,
	MultiShot = multiShotLook,
	PiercingShot = piercingShotLook,
	TrueShot = trueShotLook,
	Fireball = function(extra)
		return fireballLook(if typeof(extra[1]) == "number" then extra[1] else 8)
	end,
	HealingDart = healingDartLook,
	StoneFinisher = function()
		return finisherLook("Stone")
	end,
	ArrowFinisher = function()
		return finisherLook("Arrow")
	end,
	DartFinisher = function()
		return finisherLook("Dart")
	end,
	SpellFinisher = function(extra)
		return finisherLook("Spell", if typeof(extra[1]) == "number" then extra[1] else nil)
	end,
	LabDart = function()
		return labLook("LabDart")
	end,
	LabBanana = function()
		return labLook("LabBanana")
	end,
	LabNet = function()
		return labLook("LabNet")
	end,
	LabAcid = function(extra)
		return labLook("LabAcid", if typeof(extra[1]) == "number" then extra[1] else nil)
	end,
}

-- Proyectiles en vuelo: lo que hay que hacer cuando el servidor dice dónde se ha parado cada uno.
local landings: { [number]: (position: Vector3) -> () } = {}

-- Cuánto avanza "displacement" desde "from" antes de chocar aquí con el mundo (lo que choca y el
-- terreno) o, si no atraviesa ("pierce"), con un mono. Los jugadores y el decorado que no choca no lo
-- paran: si le da a otro jugador, lo dice el servidor.
local function localStop(from: Vector3, displacement: Vector3, params: RaycastParams, pierce: boolean): number?
	local length = displacement.Magnitude
	if length < 1e-3 then
		return nil
	end
	local direction = displacement / length
	local travelled = 0
	for _ = 1, 4 do
		local result = Workspace:Raycast(from + direction * travelled, direction * (length - travelled), params)
		if not result then
			return nil
		end
		travelled += result.Distance
		local part = result.Instance
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			if not pierce and model and CollectionService:HasTag(model, Config.Combat.EnemyTag) then
				return travelled
			end
		elseif part:IsA("Terrain") or (part:IsA("BasePart") and part.CanCollide) then
			return travelled
		end
		travelled += 0.05
		if travelled >= length then
			return nil
		end
	end
	return nil
end

-- Un proyectil del servidor (Combat/Projectiles): va recto desde "origin" a "speed" y se dibuja donde
-- está a la hora del servidor, así que aunque llegue tarde por el ping se ve donde lo ven todos. Se para
-- donde dice "ProjectileEnd" o, antes, si aquí choca con el mundo o con un mono (no espera al servidor).
-- El propio (Fase 15, V7) sale del cañón del arma (un Attachment "Muzzle" o, si no, su Handle) y en
-- Config.Combat.Headshot.MuzzleBlendSeconds se junta con la trayectoria real: solo cambia cómo se ve, no
-- dónde acierta (eso lo decide el servidor).
local function projectile(
	id: number,
	lookId: string,
	owner: Model?,
	origin: Vector3,
	direction: Vector3,
	speed: number,
	range: number,
	startTime: number,
	pierce: boolean,
	extra: { any }?,
	gravity: number?
)
	local build = LOOKS[lookId]
	if not build then
		return
	end
	local look = build(extra or {})
	local body = look.body
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if owner then { folder, owner } else { folder }
	params.IgnoreWater = true
	local limit = range
	local stopPoint: Vector3? = nil
	local travelled = 0
	local finished = false
	local connection: RBXScriptConnection? = nil
	-- Del cañón local a la trayectoria: el desfase al salir y su peso (1 → 0) según el tiempo.
	local muzzleOffset = Vector3.zero
	if owner and owner == Players.LocalPlayer.Character then
		local tool = owner:FindFirstChildOfClass("Tool")
		local muzzle = if tool then tool:FindFirstChild("Muzzle", true) else nil
		local handle = if tool then tool:FindFirstChild("Handle") else nil
		if muzzle and muzzle:IsA("Attachment") then
			muzzleOffset = muzzle.WorldPosition - origin
		elseif handle and handle:IsA("BasePart") then
			muzzleOffset = handle.Position - origin
		end
	end
	local blendSeconds = Config.Combat.Headshot.MuzzleBlendSeconds
	local function muzzleShift(elapsed: number): Vector3
		return muzzleOffset * math.max(0, 1 - elapsed / blendSeconds)
	end
	local function finish(position: Vector3)
		if finished then
			return
		end
		finished = true
		landings[id] = nil
		if connection then
			connection:Disconnect()
		end
		body.CFrame = CFrame.lookAt(position, position + direction)
		look.land(position)
	end
	landings[id] = function(position)
		local along = (position - origin):Dot(direction)
		if along <= travelled then
			finish(position)
		elseif along < limit then
			limit = along
			stopPoint = position
		end
	end
	body.CFrame = CFrame.lookAt(origin, origin + direction)
	body.Parent = folder
	if gravity then
		-- En arco: se dibuja en su punto de la parábola a la hora del servidor; se para donde choca aquí o
		-- donde dice el servidor (que va por delante del dibujo como mucho el ping).
		local velocity = direction * speed
		local function at(t: number): Vector3
			return origin + velocity * t - Vector3.yAxis * (gravity * t * t / 2)
		end
		local last = origin
		local path = 0
		landings[id] = function(position)
			finish(position)
		end
		connection = RunService.RenderStepped:Connect(function()
			local elapsed = Workspace:GetServerTimeNow() - startTime
			local point = at(math.max(elapsed, 0))
			local hit = localStop(last, point - last, params, pierce)
			if hit then
				finish(last + (point - last).Unit * hit)
				return
			end
			path += (point - last).Magnitude
			local ahead = at(elapsed + 0.02)
			local cframe = CFrame.lookAt(point, if (ahead - point).Magnitude > 1e-3 then ahead else point + direction)
				+ muzzleShift(elapsed)
			body.CFrame = cframe
			last = point
			if look.follow then
				look.follow(cframe, elapsed)
			end
			if path >= range then
				finish(point)
			end
		end)
		return
	end
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = Workspace:GetServerTimeNow() - startTime
		local target = math.min(math.max(speed * elapsed, travelled), limit)
		local from = origin + direction * travelled
		local hit = localStop(from, direction * (target - travelled), params, pierce)
		if hit then
			target = travelled + hit
			limit = target
			stopPoint = from + direction * hit
		end
		travelled = target
		local cframe = CFrame.lookAt(origin + direction * travelled, origin + direction * (travelled + 1))
			+ muzzleShift(elapsed)
		body.CFrame = cframe
		if look.follow then
			look.follow(cframe, elapsed)
		end
		if travelled >= limit - 1e-3 then
			finish(stopPoint or origin + direction * limit)
		end
	end)
end

-- El servidor dice dónde se ha parado el proyectil "id".
local function projectileEnd(id: number, position: Vector3)
	local landing = landings[id]
	if landing then
		landing(position)
	end
end

-- ===================================== Entorno (C10) =====================================

-- Rebote contra muros (Combat/Knockback): hundimiento y grietas en la pared donde ha chocado, polvo y
-- piedrecitas que caen. "normal" sale de la pared.
local function wallBang(point: Vector3, normal: Vector3)
	local crackColor = Color3.fromRGB(28, 20, 14)
	local rockColor = Color3.fromRGB(120, 95, 70)
	-- Dos ejes a lo largo de la pared.
	local reference = if math.abs(normal.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis
	local side = normal:Cross(reference).Unit
	local along = side:Cross(normal).Unit
	local surface = point + normal * 0.08
	local marks: { BasePart } = {}
	local dent = piece("Dent", Vector3.new(1.6, 1.6, 0.12), crackColor, Enum.Material.Slate)
	dent.CFrame = CFrame.lookAt(surface, surface + normal) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi))
	dent.Parent = folder
	table.insert(marks, dent)
	local count = 7
	for index = 1, count do
		local angle = index / count * 2 * math.pi + rng:NextNumber(-0.3, 0.3)
		local direction = side * math.cos(angle) + along * math.sin(angle)
		local length = rng:NextNumber(1.6, 3.4)
		local from = surface + direction * 0.5
		local to = surface + direction * length
		local crack = piece(
			"Crack",
			Vector3.new(rng:NextNumber(0.16, 0.3), 0.1, (to - from).Magnitude),
			crackColor,
			Enum.Material.Slate
		)
		-- Con el "arriba" de la pieza hacia fuera de la pared: queda pegada a ella.
		crack.CFrame = CFrame.lookAt((from + to) / 2, to, normal)
		crack.Parent = folder
		table.insert(marks, crack)
	end
	fadeAway(marks, 0.8, 1.6)
	for _ = 1, 7 do
		local size = rng:NextNumber(0.25, 0.6)
		local rock = piece("Debris", Vector3.new(size, size * 0.8, size), rockColor, Enum.Material.Slate)
		rock.CFrame = CFrame.new(point + normal * 0.6 + side * rng:NextNumber(-1, 1) + along * rng:NextNumber(-1, 1))
		local velocity = normal * rng:NextNumber(4, 10) + Vector3.new(0, rng:NextNumber(4, 12), 0)
		fling(rock, velocity, Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), 0), 0.9)
	end
	burst(point + normal, SMOKE_TEXTURE, Color3.fromRGB(165, 140, 105), 18, 2.5, 8, 1.2)
	shake(point, 25, 0.8, 0.3)
end

-- Suelo ardiendo (el Meteoro rematado): quemado y llamas pequeñas repartidas mientras dura.
local function fireZone(center: Vector3, radius: number, seconds: number)
	local scorch =
		disc(center + Vector3.new(0, 0.12, 0), radius * 0.8, Color3.fromRGB(40, 20, 12), Enum.Material.Slate, 0.55)
	scorch.Parent = folder
	for index = 1, 7 do
		local angle = index / 7 * 2 * math.pi
		local spot = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * rng:NextNumber(0.2, 0.8)
		local embers = emitter(
			FIRE_TEXTURE,
			ColorSequence.new(Color3.fromRGB(255, 180, 60), Color3.fromRGB(255, 60, 20)),
			NumberSequence.new(2, 0),
			3,
			0.9
		)
		embers.LightEmission = 1
		embers.EmissionDirection = Enum.NormalId.Top
		embers.SpreadAngle = Vector2.new(20, 20)
		embers.Rate = 8
		embers.Parent = anchorAt(spot + Vector3.new(0, 0.3, 0), seconds + 1.5)
		task.delay(seconds, function()
			embers.Enabled = false
		end)
	end
	fadeAway({ scorch }, 0.8, seconds)
end

-- Baldosas voxel que cubren el círculo de "radius" alrededor de "center" pegadas al suelo (en una ladera
-- no se entierran, como un disco plano): cada una a la altura y con la inclinación del suelo bajo ella,
-- con un color al azar de "colors". Devuelve las piezas (ya puestas).
local function groundTiles(
	center: Vector3,
	radius: number,
	size: number,
	colors: { Color3 },
	material: Enum.Material,
	transparency: number
): { BasePart }
	local params = groundParams()
	local tiles: { BasePart } = {}
	local steps = math.ceil(radius / size)
	for ix = -steps, steps do
		for iz = -steps, steps do
			local offset = Vector3.new(ix, 0, iz) * size
			if offset.Magnitude <= radius then
				local above = center + offset + Vector3.new(0, 6, 0)
				local hit = Workspace:Raycast(above, Vector3.new(0, -40, 0), params)
				local position = if hit then hit.Position else center + offset
				local normal = if hit then hit.Normal else Vector3.yAxis
				local tile = piece(
					"ZoneTile",
					Vector3.new(size * 1.04, 0.2, size * 1.04),
					colors[rng:NextInteger(1, #colors)],
					material,
					transparency
				)
				-- Apoyada en el suelo con su inclinación, sin girar en horizontal (rejilla).
				local forward = Vector3.zAxis - normal * normal.Z
				tile.CFrame = CFrame.lookAt(position + normal * 0.12, position + normal * 0.12 + forward, normal)
				tile.Parent = folder
				table.insert(tiles, tile)
			end
		end
	end
	return tiles
end

-- Hielo de la Nova: baldosas de hielo azul en dos tonos por todo el radio, con escarcha blanca y
-- destellos, que se derriten al final.
local function iceZone(center: Vector3, radius: number, seconds: number)
	local params = groundParams()
	local parts = groundTiles(
		center,
		radius,
		3,
		{ Color3.fromRGB(95, 170, 240), Color3.fromRGB(130, 195, 250) },
		Enum.Material.Ice,
		0.12
	)
	for _ = 1, 12 do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local spot = groundAt(
			center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * rng:NextNumber(0.15, 0.9),
			params
		)
		local frost = piece(
			"Frost",
			Vector3.new(rng:NextNumber(0.8, 1.6), 0.4, rng:NextNumber(0.3, 0.6)),
			Color3.fromRGB(235, 248, 255),
			Enum.Material.Ice,
			0
		)
		frost.CFrame = CFrame.new(spot + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		frost.Parent = folder
		table.insert(parts, frost)
	end
	local sparkles =
		emitter(SPARKLE_TEXTURE, ColorSequence.new(Color3.fromRGB(220, 245, 255)), NumberSequence.new(0.6, 0), 0.5, 1)
	sparkles.LightEmission = 1
	sparkles.Rate = 6
	for index = 1, 4 do
		local angle = index / 4 * 2 * math.pi
		local glints = sparkles:Clone()
		glints.Parent =
			anchorAt(center + Vector3.new(math.cos(angle), 0.6, math.sin(angle)) * radius * 0.5, seconds + 1)
		task.delay(seconds, function()
			glints.Enabled = false
		end)
	end
	sparkles:Destroy()
	fadeAway(parts, 0.6, math.max(0, seconds - 0.6))
end

-- Nube del Polvo somnífero: humo lila que se queda en el radio y baldosas lilas suaves en el suelo para
-- ver hasta dónde llega.
local function cloudZone(center: Vector3, radius: number, seconds: number)
	local area = groundTiles(
		center,
		radius,
		3,
		{ Color3.fromRGB(205, 150, 255), Color3.fromRGB(185, 130, 240) },
		Enum.Material.Neon,
		0.8
	)
	local cloud = emitter(
		SMOKE_TEXTURE,
		ColorSequence.new(Color3.fromRGB(220, 180, 255), Color3.fromRGB(170, 120, 230)),
		NumberSequence.new(radius * 0.5, radius * 0.8),
		radius * 0.4,
		2
	)
	cloud.Transparency = NumberSequence.new(0.55, 1)
	cloud.SpreadAngle = Vector2.new(180, 15)
	cloud.Acceleration = Vector3.new(0, 0.5, 0)
	cloud.Rate = 6
	cloud.Parent = anchorAt(center + Vector3.new(0, 1.5, 0), seconds + 2.5)
	cloud:Emit(8)
	task.delay(seconds, function()
		cloud.Enabled = false
	end)
	fadeAway(area, 0.5, math.max(0, seconds - 0.5))
end

local ZONE_LOOKS: { [string]: (center: Vector3, radius: number, seconds: number) -> () } = {
	Fire = fireZone,
	Ice = iceZone,
	Cloud = cloudZone,
}

-- Una zona de peligro (Combat/Zones).
local function zone(kind: string, center: Vector3, radius: number, seconds: number)
	local look = ZONE_LOOKS[kind]
	if look then
		look(center, radius, seconds)
	end
end

-- ===================================== Despacho =====================================

-- Cada efecto con los datos que manda el servidor (Combat/AbilityFx).
local EFFECTS: { [string]: (...any) -> () } = {
	Whirlwind = whirlwind, -- (personaje, segundos)
	Charge = charge, -- (personaje, segundos)
	WarCry = warCry, -- (personaje, segundos)
	Quake = quake, -- (centro en el suelo, radio)
	LeapMark = leapMark, -- (centro en el suelo, radio, segundos del salto): dónde cae el Salto del gorila
	Smash = smash, -- (suelo a los pies, hacia dónde mira, alcance, grados del cono; 360 = alrededor)
	MarkPrey = markPrey, -- (centro, radio)
	TrapSnap = trapSnap, -- (centro en el suelo, radio de captura)
	Rooted = rooted, -- (modelo, segundos)
	ArrowRain = arrowRain, -- (centro en el suelo, radio, segundos)
	TrueShotAim = trueShotAim, -- (personaje, puntería, segundos de carga): aviso del Disparo certero
	FrostNova = frostNova, -- (centro, radio)
	Frozen = frozen, -- (modelo, segundos)
	Blink = blink, -- (desde, hasta)
	Lightning = lightning, -- (desde, hasta, modelo alcanzado)
	LavaBeam = lavaBeam, -- (personaje del mago, modelo alcanzado, segundos): el Haz volcánico
	Meteor = meteor, -- (centro en el suelo, radio, segundos hasta el impacto)
	AreaHeal = areaHeal, -- (centro, radio)
	HealBurst = healBurst, -- (posición)
	Resurgence = resurgence, -- (centro, radio)
	ShieldGlare = shieldGlare, -- (personaje)
	Totem = totem, -- (posición, hacia dónde mira el médico, radio, segundos)
	SleepPowder = sleepPowder, -- (origen, centro en el suelo, radio)
	Asleep = asleep, -- (modelo, segundos)
	IceShatter = iceShatter, -- (posición): la Bola de fuego del combo rompe el hielo
	ComboComplete = comboComplete, -- (personaje, racha)
	WeaponShotFx = weaponShotFx, -- (personaje, proyectil, remate): bocanada o destello al disparar un arma a distancia
	GuardFx = guardFx, -- (personaje, "Block" | "Parry" | "Break"): la guardia (Combat/Guard)
	EvasiveFx = evasiveFx, -- (personaje): el Evasivo (Combat/Evasive; el propio cliente, DodgeController)
	-- (personaje, dirección?): la esquiva (Combat/CombatService.onDodge; el propio cliente, DodgeController y
	-- la Embestida de RoleController). Sin dirección, la saca del movimiento del personaje.
	DodgeFx = dodgeFx,
	FeintFx = feintFx, -- (personaje): el amago (Combat/Feint; el propio cliente, CombatClient/Feint)
	-- (id, aspecto de LOOKS, personaje que dispara, origen, dirección, velocidad, alcance, hora de salida
	-- del servidor, atraviesa, datos del aspecto, gravedad si va en arco): un proyectil (Combat/Projectiles)
	Projectile = projectile,
	ProjectileEnd = projectileEnd, -- (id, dónde se ha parado)
	WallBang = wallBang, -- (punto de la pared, su normal): rebote contra muros (Combat/Knockback)
	Zone = zone, -- ("Fire" | "Ice" | "Cloud", centro en el suelo, radio, segundos): Combat/Zones
	AcidPuddle = acidPuddle, -- (centro, radio, segundos): el charco del cañón de suero (Laboratorio)
	Entangled = entangled, -- (modelo, segundos): la red del lanzarredes (Laboratorio)
	-- (pieza de la boca, proyectil "LabDart" | "LabBanana" | "LabNet" | "LabAcid"): el fogonazo del arma en la vista
	-- propia (Laboratorio, FirstPersonController)
	LabMuzzle = function(part: any, style: any)
		if typeof(part) == "Instance" and part:IsA("BasePart") and typeof(style) == "string" then
			labMuzzleFlash(part, style)
		end
	end,
}

-- Dibuja un efecto en este cliente. RoleController lo usa para los movimientos propios.
function AbilityFxController.play(kind: string, ...: any)
	local effect = EFFECTS[kind]
	if effect then
		task.spawn(effect, ...)
	end
end

function AbilityFxController:Init()
	folder = Instance.new("Folder")
	folder.Name = "AbilityFx"
	folder.Parent = Workspace
end

function AbilityFxController:Start()
	Remotes.AbilityFx.OnClientEvent:Connect(function(kind: any, ...: any)
		if typeof(kind) == "string" then
			AbilityFxController.play(kind, ...)
		end
	end)
	task.spawn(watchMarks)
	task.spawn(watchPoison)
	task.spawn(watchShields)
	task.spawn(watchComboMarks)
end

return AbilityFxController
