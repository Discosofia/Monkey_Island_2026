--!strict
-- Lancha neumática de rescate (Fase 25, G4b): la de la orilla del Lobby, para la escena «Voyage» de Data/Cinematics.
--   LifeboatModel.build()  el modelo, con la proa hacia -Z y el pivote en la línea de flotación (centro del bote).
--                          PrimaryPart = "Fondo". Todo va soldado al fondo, sin anclar y sin colisión: quien lo use ancla
--                          el fondo (o todas las piezas) y lo coloca con PivotTo.
--   LifeboatModel.SEATS    plazas de la tripulación (marco del pivote): cadera sobre el banco o sobre el suelo.
-- La geometría y los colores copian los de LobbyBuilder.buildLifeboat (que no usa este módulo: allí las piezas van
-- ancladas, con colisión y con el aviso de zarpar). Si cambias uno, cambia el otro.

local RunService = game:GetService("RunService")

local ORANGE = Color3.fromRGB(240, 110, 30)
local WHITE = Color3.fromRGB(232, 232, 226)
local GLASS = Color3.fromRGB(45, 65, 85)
local ALUMINIUM = Color3.fromRGB(170, 175, 180)
local LANTERN = Color3.fromRGB(255, 200, 120)
local DARK = Color3.fromRGB(25, 25, 28)

local FLOOR_CENTER = Vector3.new(0, 0.4, -0.3) -- centro del fondo en el marco del pivote

local LifeboatModel = {}

-- Plazas por actor de la escena (más "player", la copia del avatar). pos: donde apoya la cadera (cara de arriba del
-- banco o del suelo); knee: ángulo de la rodilla en grados (-90 = pantorrilla colgando, 0 = pierna estirada al frente).
-- Repartidas a lo largo de la lancha: dos en el banco de popa (x ±1,0, lo más abierto que deja el banco, que llega a
-- ±1,2, y los flotadores, que empiezan en ±1,4), dos sentados sobre los flotadores rectos (cadera hacia el lado de dentro de la cara de
-- arriba, x ±1,7 e y = 1,55, con las piernas estiradas hacia la proa a lo largo del tubo, de z -0,3 a -1,4, delante de la
-- consola, que ocupa |x| < 0,7) y el avatar delante y al centro con las piernas en el suelo (hasta z ≈ -4,5, donde
-- los flotadores ya se cierran). Todo va soldado al fondo, así que el balanceo no saca a nadie del bote.
LifeboatModel.SEATS = {
	guerrero = { pos = Vector3.new(-1.0, 1.5, 2.6), knee = -90 },
	mago = { pos = Vector3.new(1.0, 1.5, 2.6), knee = -90 },
	cazador = { pos = Vector3.new(-1.7, 1.55, -0.3), knee = 0 },
	medico = { pos = Vector3.new(1.7, 1.55, -0.3), knee = 0 },
	player = { pos = Vector3.new(0, 0.6, -3.4), knee = 0 },
} :: { [string]: { pos: Vector3, knee: number } }

-- Espuma (opción spray). Caudales a calidad alta, en partículas por segundo: cada lado de la proa y la estela. En
-- Medium se usa el 70 % y en Low el 50 %. Con vida máxima de 0,9 s, el máximo vivo es 2 x 22 x 0,9 + 30 x 0,9 = 67 y,
-- con la ráfaga de 12 por lado, unas 91 a la vez (Low: ~46).
local BOW_RATE, WAKE_RATE, BURST_COUNT = 22, 30, 12
local FOAM_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- la misma que el humo de AbilityFxController
local FOAM_COLOR = Color3.fromRGB(205, 230, 245)

-- Multiplicador de caudal según FxQuality (solo existe en el cliente; en el servidor o si falla, el de Medium).
local function foamScale(): number
	if not RunService:IsClient() then
		return 0.7
	end
	local ok, quality = pcall(function()
		return require(script.Parent.FxQuality).get()
	end)
	if ok and quality == "High" then
		return 1
	elseif ok and quality == "Low" then
		return 0.5
	end
	return 0.7
end

-- Un emisor de espuma colgado de "attachment". El eje Y del attachment es la dirección de salida.
local function foamEmitter(attachment: Attachment, rate: number, speed: NumberRange, spread: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Espuma"
	emitter.Texture = FOAM_TEXTURE
	emitter.Color = ColorSequence.new(FOAM_COLOR)
	emitter.LightEmission = 0.1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.42),
		NumberSequenceKeypoint.new(1, 1.4),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.6, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = speed
	emitter.SpreadAngle = Vector2.new(spread, spread)
	emitter.Acceleration = Vector3.new(0, -14, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = rate
	emitter.Parent = attachment
	return emitter
end

-- Opciones: spray = true añade la espuma de la proa y del motor (sin piezas: attachments del Fondo y emisores) y
-- burstTimes = { segundos } da una ráfaga extra por lado a cada instante, contado desde que se construye el modelo
-- (la escena lo construye al empezar). Las ráfagas paran solas cuando el modelo se destruye.
function LifeboatModel.build(options: { spray: boolean?, burstTimes: { number }? }?): Model
	local model = Instance.new("Model")
	model.Name = "Lifeboat"

	local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = cframe
		part.Color = color
		part.Material = material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Parent = model
		return part
	end

	-- Fondo: raíz del modelo y pivote en la línea de flotación.
	local floor = newPart(
		"Fondo",
		Vector3.new(3.6, 0.4, 10.5),
		CFrame.new(FLOOR_CENTER),
		Color3.fromRGB(70, 75, 80),
		Enum.Material.Metal
	)
	floor.PivotOffset = CFrame.new(-FLOOR_CENTER)
	floor.Massless = false
	model.PrimaryPart = floor

	-- Suelda "part" al fondo en la posición que ya tiene.
	local function weld(part: Part): Part
		local joint = Instance.new("Weld")
		joint.Part0 = floor
		joint.Part1 = part
		joint.C0 = floor.CFrame:ToObjectSpace(part.CFrame)
		joint.Parent = part
		return part
	end

	local function box(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
		return weld(newPart(name, size, cframe, color, material))
	end

	local function cylinder(
		name: string,
		diameter: number,
		from: Vector3,
		to: Vector3,
		color: Color3,
		material: Enum.Material
	): Part
		local direction = to - from
		-- Con un tramo vertical, lookAt necesita otro vector "arriba".
		local up = if math.abs(direction.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
		local part = newPart(
			name,
			Vector3.new(direction.Magnitude, diameter, diameter),
			CFrame.lookAt((from + to) / 2, to, up) * CFrame.Angles(0, math.pi / 2, 0),
			color,
			material
		)
		part.Shape = Enum.PartType.Cylinder
		return weld(part)
	end

	local function ball(name: string, diameter: number, position: Vector3, color: Color3, material: Enum.Material): Part
		local part = newPart(name, Vector3.one * diameter, CFrame.new(position), color, material)
		part.Shape = Enum.PartType.Ball
		return weld(part)
	end

	-- Flotadores: rectos a los lados y cerrándose en la proa.
	for _, side in { -1, 1 } do
		cylinder(
			"Flotador",
			1.6,
			Vector3.new(side * 2.2, 0.9, 5.2),
			Vector3.new(side * 2.2, 0.9, -2.5),
			ORANGE,
			Enum.Material.Fabric
		)
		cylinder(
			"Flotador",
			1.6,
			Vector3.new(side * 2.2, 0.9, -2.5),
			Vector3.new(0, 1.1, -6.2),
			ORANGE,
			Enum.Material.Fabric
		)
		ball("Tapa", 1.6, Vector3.new(side * 2.2, 0.9, 5.2), ORANGE, Enum.Material.Fabric)
		-- Cabo de agarre a lo largo del flotador.
		cylinder(
			"Cabo",
			0.15,
			Vector3.new(side * 2.9, 1.4, 4),
			Vector3.new(side * 2.9, 1.4, -2),
			WHITE,
			Enum.Material.Fabric
		)
	end
	ball("Proa", 1.8, Vector3.new(0, 1.1, -6.2), ORANGE, Enum.Material.Fabric)
	box("Espejo", Vector3.new(4.2, 1.6, 0.4), CFrame.new(0, 1, 5.4), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)

	-- Consola con parabrisas y volante.
	box("Consola", Vector3.new(1.4, 1.6, 1.1), CFrame.new(0, 1.4, 0.5), WHITE, Enum.Material.SmoothPlastic)
	box(
		"Parabrisas",
		Vector3.new(1.4, 0.8, 0.1),
		CFrame.new(0, 2.6, 0.05) * CFrame.Angles(math.rad(-20), 0, 0),
		GLASS,
		Enum.Material.Glass
	)
	local wheel = box(
		"Volante",
		Vector3.new(0.15, 0.9, 0.9),
		CFrame.new(0, 2.3, 1.1) * CFrame.Angles(0, math.pi / 2, math.rad(30)),
		Color3.fromRGB(30, 30, 30),
		Enum.Material.SmoothPlastic
	)
	wheel.Shape = Enum.PartType.Cylinder
	box(
		"Asiento",
		Vector3.new(2.4, 0.9, 1.2),
		CFrame.new(0, 1.05, 2.6),
		Color3.fromRGB(40, 40, 45),
		Enum.Material.Fabric
	)

	-- Motor fueraborda.
	box("Motor", Vector3.new(1.1, 1.6, 1.3), CFrame.new(0, 2.2, 6), DARK, Enum.Material.SmoothPlastic)
	box("FranjaMotor", Vector3.new(1.15, 0.3, 1.35), CFrame.new(0, 2.4, 6), ORANGE, Enum.Material.SmoothPlastic)
	box("Pie", Vector3.new(0.4, 2.2, 0.5), CFrame.new(0, 0.5, 6.1), DARK, Enum.Material.Metal)

	-- Luz de navegación en un mástil corto.
	box("Mastil", Vector3.new(0.2, 2.4, 0.2), CFrame.new(0, 3.2, 3.4), ALUMINIUM, Enum.Material.Metal)
	local lamp = ball("Luz", 0.5, Vector3.new(0, 4.5, 3.4), Color3.new(1, 1, 1), Enum.Material.Neon)
	local point = Instance.new("PointLight")
	point.Color = LANTERN
	point.Range = 18
	point.Brightness = 2
	point.Shadows = true
	point.Parent = lamp

	if options and options.spray then
		-- En la escena la linterna del mástil casi no ilumina: a 2-3 studs de la tripulación la lavaba de blanco.
		point.Brightness = 0.4
		point.Range = 10
		local scale = foamScale()
		local bowEmitters: { ParticleEmitter } = {}
		-- Costado de la proa, a ras de agua: sale hacia fuera y arriba (el Y del attachment, inclinado 40°).
		for _, side in { -1, 1 } do
			local attachment = Instance.new("Attachment")
			attachment.Name = "EspumaProa"
			attachment.CFrame = CFrame.new(Vector3.new(side * 2.0, 0.1, -3.4) - FLOOR_CENTER)
				* CFrame.Angles(0, 0, -side * math.rad(40))
			attachment.Parent = floor
			table.insert(bowEmitters, foamEmitter(attachment, BOW_RATE * scale, NumberRange.new(4, 7), 18))
		end
		-- Estela tras el motor: hacia atrás (+Z) y algo arriba.
		local wake = Instance.new("Attachment")
		wake.Name = "EstelaMotor"
		wake.CFrame = CFrame.new(Vector3.new(0, 0.1, 6.9) - FLOOR_CENTER) * CFrame.Angles(math.rad(65), 0, 0)
		wake.Parent = floor
		foamEmitter(wake, WAKE_RATE * scale, NumberRange.new(2.5, 4.5), 14)

		for _, delay in options.burstTimes or {} do
			task.delay(delay, function()
				if not model.Parent then
					return -- la escena acabó y el modelo ya no está
				end
				for _, emitter in bowEmitters do
					emitter:Emit(math.max(1, math.round(BURST_COUNT * scale)))
				end
			end)
		end
	end

	return model
end

return LifeboatModel
