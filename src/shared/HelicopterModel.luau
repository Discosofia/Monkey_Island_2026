--!strict
-- Helicóptero de rescate voxel (Fase 25, G3b): lo usa la escena «Rescue» de Data/Cinematics.
--   HelicopterModel.build()    el modelo, con el frente hacia -Z, centrado en su pieza raíz "Body" (el pivote).
--   HelicopterModel.animate(m) hace girar los dos rotores (cliente; se para solo al destruir el modelo).
--
-- Construcción: "Body" es la raíz (PrimaryPart, anclada); el resto va soldado a ella con Weld, parenteado a la
-- pieza soldada (así VoxelMerge los fusiona). Los dos rotores cuelgan de Body con un Motor6D (MainRotorMotor,
-- TailRotorMotor): la hélice es la pieza que gira, y las aspas van soldadas al buje. Un buje con Motor6D no se
-- fusiona nunca (VoxelMerge solo admite soldaduras como hijos), así que no hace falta nombrarlo en KEEP.
-- Nada colisiona. Paleta: blanco roto, naranja de rescate, gris oscuro, cristal azul claro, plátano amarillo.
-- El verde está prohibido (solo es la curación).
--
-- Medidas (studs): ~11,6 de largo (de -4,2 a 7,4 en Z), ~5,8 de fuselaje con patines y 4 con el mástil, 4,4 de
-- ancho, rotor principal de 16 de diámetro. 60 bloques de diseño (con la cabina hueca, la puerta abierta por el
-- costado derecho y ocho cojines).

local RunService = game:GetService("RunService")

local WHITE = Color3.fromRGB(240, 240, 235)
local ORANGE = Color3.fromRGB(232, 106, 23)
local DARK = Color3.fromRGB(60, 62, 66)
local GLASS = Color3.fromRGB(120, 200, 230)
local BANANA = Color3.fromRGB(255, 214, 64)
local SPOT = Color3.fromRGB(255, 244, 200)

local GLASS_TRANSPARENCY = 0.25
local MAIN_SPEED = math.rad(700) -- rad/s del rotor principal (se ve girar sin hacerse un borrón)
local TAIL_SPEED = math.rad(1100) -- rad/s del rotor de cola

local HelicopterModel = {}

-- Plazas de la cabina: posición local (marco de "Body", frente en -Z, puerta en +X) de la cara de arriba del cojín,
-- donde apoya la cadera de quien se sienta. El piloto va delante a la derecha (el asiento delantero sigue siendo el
-- mismo de siempre; su cojín queda un poco detrás para no clavarle las rodillas en el respaldo). Los pasajeros, en
-- 3 filas x 2, de la plaza más cercana a la puerta (centro de la abertura, z = 0) a la más lejana.
HelicopterModel.PILOT_SEAT = Vector3.new(1.0, -0.7, -2.1)
HelicopterModel.SEATS = {
	Vector3.new(0.9, -0.7, 0.5),
	Vector3.new(0.9, -0.7, -0.9),
	Vector3.new(0.9, -0.7, 1.9),
	Vector3.new(-0.9, -0.7, 0.5),
	Vector3.new(-0.9, -0.7, -0.9),
	Vector3.new(-0.9, -0.7, 1.9),
} :: { Vector3 }

-- Pieza base de todo el modelo: sin colisión, con cuerpo liso.
local function newPart(model: Model, name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Parent = model
	return part
end

-- Un bloque soldado a "anchor": "center" es su centro en el marco de "anchor". Devuelve la pieza.
local function block(model: Model, anchor: BasePart, name: string, size: Vector3, center: Vector3, color: Color3): Part
	local part = newPart(model, name, size, color)
	part.CFrame = anchor.CFrame * CFrame.new(center)
	local weld = Instance.new("Weld")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.C0 = CFrame.new(center)
	weld.Parent = part
	return part
end

-- Buje de un rotor: cuelga de "body" con un Motor6D cuyo C0 es la posición de reposo.
local function rotorHub(model: Model, body: BasePart, name: string, size: Vector3, center: Vector3): Part
	local hub = newPart(model, name, size, DARK)
	hub.CFrame = body.CFrame * CFrame.new(center)
	local motor = Instance.new("Motor6D")
	motor.Name = name .. "Motor"
	motor.Part0 = body
	motor.Part1 = hub
	motor.C0 = CFrame.new(center)
	motor.Parent = hub
	return hub
end

function HelicopterModel.build(): Model
	local model = Instance.new("Model")
	model.Name = "Helicopter"

	-- "Body" es solo la raíz (pivote): invisible y mínima, en el centro de la cabina (antes era el bloque macizo de
	-- 4,4 x 2,4 x 5,6, que ahora van como suelo, paredes y techo). Las coordenadas de los demás bloques no cambian.
	local body = newPart(model, "Body", Vector3.new(0.2, 0.2, 0.2), WHITE)
	body.Transparency = 1
	body.Anchored = true
	body.Massless = false
	model.PrimaryPart = body

	-- Cabina hueca (x de -2,2 a 2,2; y de -1,2 a 1,2; z de -2,8 a 2,8). Pared izquierda llena con su ventana; la
	-- derecha es la puerta corredera abierta: solo el antepecho bajo y un montante delante y otro detrás.
	block(model, body, "Floor", Vector3.new(4.0, 0.2, 5.6), Vector3.new(0, -1.1, 0), DARK)
	block(model, body, "Ceiling", Vector3.new(4.4, 0.2, 5.6), Vector3.new(0, 1.1, 0), WHITE)
	block(model, body, "WallLeft", Vector3.new(0.2, 2.4, 5.6), Vector3.new(-2.1, 0, 0), WHITE)
	block(model, body, "SillRight", Vector3.new(0.2, 1.0, 5.6), Vector3.new(2.1, -0.7, 0), WHITE)
	for _, z in { -2.6, 2.6 } do
		block(model, body, "PillarRight", Vector3.new(0.2, 1.4, 0.4), Vector3.new(2.1, 0.5, z), WHITE)
	end
	block(model, body, "RearWall", Vector3.new(4.4, 2.4, 0.2), Vector3.new(0, 0, 2.7), WHITE)
	for side = -1, 1, 2 do
		block(model, body, "Stripe", Vector3.new(0.2, 0.6, 5.2), Vector3.new(side * 2.25, -0.55, 0.2), ORANGE)
	end
	block(model, body, "Window", Vector3.new(0.12, 0.9, 2.0), Vector3.new(-2.22, 0.5, -1.0), GLASS).Transparency =
		GLASS_TRANSPARENCY
	block(model, body, "Roof", Vector3.new(4.0, 0.8, 4.6), Vector3.new(0, 1.6, 0.2), WHITE)

	-- Banco: respaldo contra la pared izquierda y contra el portón, y un cojín por plaza (piloto, copiloto y seis
	-- pasajeros; SEATS dice dónde se sienta cada uno).
	block(model, body, "BenchLeft", Vector3.new(0.3, 0.9, 3.7), Vector3.new(-1.85, -0.55, 0.55), DARK)
	block(model, body, "BenchRear", Vector3.new(3.4, 0.9, 0.3), Vector3.new(0, -0.55, 2.55), DARK)
	local pilot = HelicopterModel.PILOT_SEAT
	local cushions = { pilot, Vector3.new(-pilot.X, pilot.Y, pilot.Z) } -- piloto (derecha) y copiloto (vacío)
	for _, seat in HelicopterModel.SEATS do
		table.insert(cushions, seat)
	end
	for _, seat in cushions do
		-- La posición del asiento es la cara de arriba del cojín.
		block(model, body, "Cushion", Vector3.new(1.1, 0.3, 0.9), Vector3.new(seat.X, seat.Y - 0.15, seat.Z), DARK)
	end

	-- Morro: cristal sobre una barbilla blanca, con una visera, los asientos y el salpicadero dentro.
	block(model, body, "NoseGlass", Vector3.new(4.0, 1.8, 1.4), Vector3.new(0, 0.3, -3.5), GLASS).Transparency =
		GLASS_TRANSPARENCY
	block(model, body, "Chin", Vector3.new(3.6, 0.8, 1.4), Vector3.new(0, -1.0, -3.5), WHITE)
	block(model, body, "Visor", Vector3.new(4.0, 0.5, 1.6), Vector3.new(0, 1.45, -3.4), WHITE)
	for side = -1, 1, 2 do
		block(model, body, "SeatBack", Vector3.new(1.1, 1.3, 0.4), Vector3.new(side * 1.0, 0, -2.9), DARK)
	end
	block(model, body, "Dash", Vector3.new(3.4, 0.4, 0.5), Vector3.new(0, -0.3, -3.9), DARK)
	-- Foco bajo el morro.
	local spot = block(model, body, "Spot", Vector3.new(0.9, 0.3, 0.9), Vector3.new(0, -1.55, -3.5), SPOT)
	spot.Material = Enum.Material.Neon

	-- Portón trasero oscuro con una franja naranja (se ve bien por detrás).
	block(model, body, "RearHatch", Vector3.new(3.2, 1.6, 0.12), Vector3.new(0, 0, 2.86), DARK)
	block(model, body, "RearBand", Vector3.new(3.2, 0.4, 0.14), Vector3.new(0, 0, 2.86), ORANGE)

	-- Motor sobre el techo y mástil.
	block(model, body, "Engine", Vector3.new(2.4, 0.9, 2.4), Vector3.new(0, 2.45, 0.6), DARK)
	block(model, body, "Mast", Vector3.new(0.7, 0.7, 0.7), Vector3.new(0, 3.25, 0.6), DARK)

	-- Cola: viga con franja naranja, aleta, estabilizador y emblema de plátano en los dos lados de la aleta.
	block(model, body, "TailBoom", Vector3.new(1.0, 1.0, 4.3), Vector3.new(0, 0.9, 4.85), WHITE)
	block(model, body, "TailBand", Vector3.new(1.1, 0.3, 3.8), Vector3.new(0, 0.9, 4.85), ORANGE)
	block(model, body, "Fin", Vector3.new(0.4, 1.6, 1.4), Vector3.new(0, 2.2, 6.3), WHITE)
	block(model, body, "FinCap", Vector3.new(0.4, 0.6, 1.4), Vector3.new(0, 3.3, 6.3), ORANGE)
	block(model, body, "BananaUp", Vector3.new(0.5, 0.8, 0.4), Vector3.new(0, 2.0, 6.75), BANANA)
	block(model, body, "BananaBase", Vector3.new(0.5, 0.4, 0.9), Vector3.new(0, 1.8, 6.25), BANANA)
	block(model, body, "Stabilizer", Vector3.new(3.2, 0.2, 0.9), Vector3.new(0, 1.0, 5.9), WHITE)
	for side = -1, 1, 2 do
		block(model, body, "StabilizerTip", Vector3.new(0.4, 0.2, 0.9), Vector3.new(side * 1.8, 1.0, 5.9), ORANGE)
	end

	-- Patines: dos travesaños largos sobre cuatro patas unidas por dos barras.
	for side = -1, 1, 2 do
		block(model, body, "Skid", Vector3.new(0.4, 0.3, 7.0), Vector3.new(side * 1.9, -2.7, -0.2), DARK)
		for _, z in { -1.8, 1.6 } do
			block(model, body, "SkidLeg", Vector3.new(0.3, 1.35, 0.3), Vector3.new(side * 1.9, -1.875, z), DARK)
		end
	end
	for _, z in { -1.8, 1.6 } do
		block(model, body, "SkidBar", Vector3.new(3.8, 0.3, 0.3), Vector3.new(0, -2.3, z), DARK)
	end

	-- Rotor principal (16 de diámetro): dos aspas en cruz con la punta naranja.
	local main = rotorHub(model, body, "MainRotor", Vector3.new(1.0, 0.3, 1.0), Vector3.new(0, 3.75, 0.6))
	block(model, main, "Blade", Vector3.new(13, 0.15, 0.9), Vector3.zero, DARK)
	block(model, main, "Blade", Vector3.new(0.9, 0.15, 13), Vector3.new(0, 0.1, 0), DARK)
	for side = -1, 1, 2 do
		block(model, main, "BladeTip", Vector3.new(1.5, 0.15, 0.9), Vector3.new(side * 7.25, 0, 0), ORANGE)
		block(model, main, "BladeTip", Vector3.new(0.9, 0.15, 1.5), Vector3.new(0, 0.1, side * 7.25), ORANGE)
	end

	-- Rotor de cola, en el costado derecho de la aleta; gira alrededor de X.
	local tail = rotorHub(model, body, "TailRotor", Vector3.new(0.4, 0.3, 0.3), Vector3.new(0.4, 3.1, 6.6))
	block(model, tail, "TailBlade", Vector3.new(0.1, 1.8, 0.3), Vector3.zero, DARK)
	block(model, tail, "TailBlade", Vector3.new(0.1, 0.3, 1.8), Vector3.new(0.04, 0, 0), DARK)

	return model
end

-- Hace girar los rotores a cada fotograma. Se para solo al destruir el modelo o al sacarlo del DataModel
-- (después de haber estado dentro: se puede llamar antes de ponerle padre).
function HelicopterModel.animate(model: Model)
	local main = model:FindFirstChild("MainRotorMotor", true)
	local tail = model:FindFirstChild("TailRotorMotor", true)
	if not (main and main:IsA("Motor6D") and tail and tail:IsA("Motor6D")) then
		warn("HelicopterModel.animate: faltan los motores de los rotores")
		return
	end
	local mainBase, tailBase = main.C0, tail.C0
	local mainAngle, tailAngle = 0, 0
	local connection: RBXScriptConnection? = nil
	local seenInGame = false

	local function stop()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end

	connection = RunService.PreRender:Connect(function(dt: number)
		if model:IsDescendantOf(game) then
			seenInGame = true
		elseif seenInGame then
			stop()
			return
		end
		mainAngle = (mainAngle + MAIN_SPEED * dt) % (math.pi * 2)
		tailAngle = (tailAngle + TAIL_SPEED * dt) % (math.pi * 2)
		main.C0 = mainBase * CFrame.Angles(0, mainAngle, 0)
		tail.C0 = tailBase * CFrame.Angles(tailAngle, 0, 0)
	end)
	model.Destroying:Connect(stop)
end

return HelicopterModel
