--!strict
-- Modelos de las mascotas (Fase 5): una figura de piezas simples por especie, con partes animadas
-- (alas que baten, patas que andan, colas que se mueven). Los crean los clientes (Lobby e Isla) para
-- que sigan a su dueño (UI/PetFollowers); el servidor no los conoce.
-- Se construyen alrededor de una pieza invisible "Root" (el pivote), con -Z hacia delante.
-- Atributos del modelo:
--   Motion  "Walk" (por el suelo), "Hop" (a saltos), "Fly" (vuela alto) o "Hover" (flota cerca)
--   Height  altura del pivote sobre la parte más baja, para apoyarlo en el suelo

local Pets = require(script.Parent.Data.Pets)

export type Motion = "Walk" | "Hop" | "Fly" | "Hover"

type Shape = "Ball" | "Oval" | "Block" | "Cylinder" | "Wedge"

type Joint = {
	part: BasePart,
	hinge: CFrame,
	offset: CFrame,
	axis: Vector3,
	amplitude: number,
	speed: number,
	phase: number,
	gait: boolean, -- solo se mueve mientras el dueño anda
}

type Rig = { model: Model, scale: number, joints: { Joint } }

local WHITE = Color3.fromRGB(245, 245, 238)
local BLACK = Color3.fromRGB(22, 22, 26)
local CREAM = Color3.fromRGB(235, 215, 175)
-- Gira un cilindro (eje X) para ponerlo de pie.
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local rigs: { [Model]: { Joint } } = {}

local PetModels = {}

local function scaled(rig: Rig, cframe: CFrame): CFrame
	return CFrame.new(cframe.Position * rig.scale) * cframe.Rotation
end

local function piece(
	rig: Rig,
	name: string,
	shape: Shape,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	local part: BasePart
	if shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		if shape == "Ball" then
			block.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			block.Shape = Enum.PartType.Cylinder
		elseif shape == "Oval" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = block
		end
		part = block
	end
	part.Name = name
	part.Size = size * rig.scale
	part.CFrame = scaled(rig, cframe)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = rig.model
	return part
end

-- Hace que una pieza gire alrededor de una bisagra (en coordenadas del modelo, sin escalar).
local function joint(
	rig: Rig,
	part: BasePart,
	hinge: CFrame,
	axis: Vector3,
	amplitude: number,
	speed: number,
	phase: number,
	gait: boolean
)
	local hingeFrame = scaled(rig, hinge)
	table.insert(rig.joints, {
		part = part,
		hinge = hingeFrame,
		offset = hingeFrame:Inverse() * part.CFrame,
		axis = axis,
		amplitude = amplitude,
		speed = speed,
		phase = phase,
		gait = gait,
	})
end

local function eyes(rig: Rig, center: Vector3, spread: number, diameter: number, iris: Color3?, glow: boolean?)
	for _, side in { -1, 1 } do
		local position = center + Vector3.new(side * spread, 0, 0)
		if glow then
			piece(rig, "Eye", "Ball", Vector3.one * diameter, CFrame.new(position), iris or WHITE, Enum.Material.Neon)
		else
			piece(rig, "Eye", "Ball", Vector3.one * diameter, CFrame.new(position), WHITE)
			piece(
				rig,
				"Pupil",
				"Ball",
				Vector3.one * diameter * 0.6,
				CFrame.new(position + Vector3.new(side * diameter * 0.08, 0.02, -diameter * 0.3)),
				iris or BLACK
			)
			-- Brillo en la pupila: da vida a la mirada.
			piece(
				rig,
				"Glint",
				"Ball",
				Vector3.one * diameter * 0.22,
				CFrame.new(position + Vector3.new(side * diameter * 0.02, diameter * 0.17, -diameter * 0.56)),
				WHITE,
				Enum.Material.Neon
			)
		end
	end
end

-- Óvalo alargado entre dos puntos (brazos, muslos): sus extremos redondos tapan las juntas.
local function capsule(rig: Rig, name: string, from: Vector3, to: Vector3, width: number, color: Color3): BasePart
	local length = (to - from).Magnitude + width * 0.5
	return piece(
		rig,
		name,
		"Oval",
		Vector3.new(width, width, length),
		CFrame.lookAt((from + to) / 2, to),
		color,
		Enum.Material.Fabric
	)
end

-- Pieza plana pegada a una superficie, mirando hacia "normal" (manchas, placas, parches).
local function patch(rig: Rig, name: string, size: Vector3, position: Vector3, normal: Vector3, color: Color3): BasePart
	return piece(rig, name, "Oval", size, CFrame.lookAt(position, position + normal.Unit), color)
end

-- Cuatro patas (delante izquierda/derecha, detrás izquierda/derecha) que andan en diagonal, cada
-- una con su pie (del color "paw", o del de la pata).
local function legs(
	rig: Rig,
	color: Color3,
	front: number,
	back: number,
	spread: number,
	y: number,
	size: Vector3,
	paw: Color3?
)
	local positions = {
		Vector3.new(-spread, y, front),
		Vector3.new(spread, y, front),
		Vector3.new(-spread, y, back),
		Vector3.new(spread, y, back),
	}
	local phases = { 0, math.pi, math.pi, 0 }
	for i, position in positions do
		local hinge = CFrame.new(position + Vector3.new(0, size.Y / 2, 0))
		local leg = piece(rig, "Leg", "Oval", size, CFrame.new(position), color)
		joint(rig, leg, hinge, Vector3.xAxis, 0.55, 9, phases[i], true)
		local foot = piece(
			rig,
			"Paw",
			"Oval",
			Vector3.new(size.X * 1.25, size.Y * 0.32, size.Z * 1.45),
			CFrame.new(position + Vector3.new(0, -size.Y * 0.4, -size.Z * 0.2)),
			paw or color
		)
		joint(rig, foot, hinge, Vector3.xAxis, 0.55, 9, phases[i], true)
	end
end

-- Alas abiertas que baten (bisagra junto al cuerpo).
local function wing(
	rig: Rig,
	side: number,
	hinge: Vector3,
	parts: { { size: Vector3, offset: Vector3, color: Color3 } },
	amplitude: number,
	speed: number
)
	for _, layer in parts do
		local position = hinge + Vector3.new(side * layer.offset.X, layer.offset.Y, layer.offset.Z)
		local feather = piece(rig, "Wing", "Oval", layer.size, CFrame.new(position), layer.color)
		joint(rig, feather, CFrame.new(hinge), Vector3.zAxis, amplitude * side, speed, 0, false)
	end
end

-- Cola que se mueve de lado a lado. Opcional: punta de otro color ("tip") y anillos ("bands").
local function tail(
	rig: Rig,
	color: Color3,
	base: Vector3,
	size: Vector3,
	lift: number,
	wag: number,
	tip: Color3?,
	bands: Color3?
)
	local direction = Vector3.new(0, math.sin(lift), math.cos(lift))
	local rotation = CFrame.Angles(-lift, 0, 0)
	local hinge = CFrame.new(base)
	local part = piece(rig, "Tail", "Oval", size, CFrame.new(base + direction * size.Z / 2) * rotation, color)
	joint(rig, part, hinge, Vector3.yAxis, wag, 5, 0, false)

	local function ring(name: string, along: number, length: number, ringColor: Color3)
		local ringPart = piece(
			rig,
			name,
			"Oval",
			Vector3.new(size.X * 1.12, size.Y * 1.12, length),
			CFrame.new(base + direction * along) * rotation,
			ringColor
		)
		joint(rig, ringPart, hinge, Vector3.yAxis, wag, 5, 0, false)
	end
	if bands then
		for _, fraction in { 0.45, 0.62, 0.78 } do
			ring("TailBand", size.Z * fraction, 0.14, bands)
		end
	end
	if tip then
		ring("TailTip", size.Z - 0.2, 0.4, tip)
	end
end

type CatOptions = { spots: Color3?, crystal: boolean?, eyeColor: Color3, earSize: number }

local function cat(rig: Rig, coat: Color3, options: CatOptions)
	local material = if options.crystal then Enum.Material.Glass else nil
	local light = coat:Lerp(WHITE, 0.45)
	piece(rig, "Body", "Oval", Vector3.new(0.95, 0.85, 2.1), CFrame.new(0, 0, 0), coat, material)
	piece(rig, "Chest", "Oval", Vector3.new(0.8, 0.8, 0.9), CFrame.new(0, 0.05, -0.75), coat, material)
	piece(rig, "Belly", "Oval", Vector3.new(0.6, 0.4, 1.3), CFrame.new(0, -0.25, -0.1), light, material)
	piece(rig, "Head", "Ball", Vector3.one * 0.85, CFrame.new(0, 0.5, -1.25), coat, material)
	piece(rig, "Muzzle", "Oval", Vector3.new(0.5, 0.32, 0.4), CFrame.new(0, 0.36, -1.58), light, material)
	piece(rig, "Nose", "Ball", Vector3.one * 0.14, CFrame.new(0, 0.48, -1.78), Color3.fromRGB(70, 40, 45))
	piece(rig, "Mouth", "Block", Vector3.new(0.03, 0.1, 0.03), CFrame.new(0, 0.38, -1.775), Color3.fromRGB(60, 35, 40))
	piece(rig, "Neck", "Oval", Vector3.new(0.62, 0.7, 0.6), CFrame.new(0, 0.32, -1.02), coat, material)
	local innerEar = if options.crystal then coat else Color3.fromRGB(225, 150, 150)
	local accent = options.spots or coat:Lerp(BLACK, 0.35)
	for _, side in { -1, 1 } do
		local ear = CFrame.new(side * 0.26, 0.95 + options.earSize / 2 - 0.15, -1.2) * CFrame.Angles(0, 0, -side * 0.25)
		piece(rig, "Ear", "Wedge", Vector3.new(0.12, options.earSize, 0.28), ear, coat, material)
		-- Interior de la oreja, asomando por la cara delantera.
		piece(
			rig,
			"InnerEar",
			"Wedge",
			Vector3.new(0.07, options.earSize * 0.7, 0.18),
			ear * CFrame.new(0, -options.earSize * 0.12, -0.05),
			innerEar,
			material
		)
		-- Bigotes: tres por lado, abiertos en abanico y hacia atrás.
		for k = -1, 1 do
			piece(
				rig,
				"Whisker",
				"Block",
				Vector3.new(0.5, 0.025, 0.025),
				CFrame.new(side * 0.42, 0.36 + k * 0.05, -1.55) * CFrame.Angles(0, -side * 0.35, side * k * 0.2),
				Color3.fromRGB(240, 240, 230)
			)
		end
		-- Raya de la mejilla, desde el ojo hacia abajo.
		local cheek = Vector3.new(side * 0.31, 0.44, -1.53)
		piece(
			rig,
			"Stripe",
			"Oval",
			Vector3.new(0.06, 0.2, 0.04),
			CFrame.lookAt(cheek, cheek + (cheek - Vector3.new(0, 0.5, -1.25))) * CFrame.Angles(0, 0, side * 0.4),
			accent
		)
	end
	eyes(rig, Vector3.new(0, 0.62, -1.57), 0.19, 0.2, options.eyeColor, options.crystal)
	legs(rig, coat, -0.65, 0.65, 0.3, -0.6, Vector3.new(0.28, 0.75, 0.3), light)
	tail(rig, coat, Vector3.new(0, 0.2, 0.95), Vector3.new(0.22, 0.22, 1.5), 0.55, 0.5, accent, options.spots)
	if options.spots then
		local spots = {
			Vector3.new(0.43, 0.12, -0.45),
			Vector3.new(0.44, -0.08, 0.15),
			Vector3.new(0.4, 0.14, 0.6),
			Vector3.new(-0.43, 0.12, -0.45),
			Vector3.new(-0.44, -0.08, 0.15),
			Vector3.new(-0.4, 0.14, 0.6),
			Vector3.new(0.18, 0.4, -0.15),
			Vector3.new(-0.18, 0.4, 0.3),
			Vector3.new(0.15, 0.38, 0.75),
			Vector3.new(0.05, 0.82, -1.15),
		}
		for _, position in spots do
			local normal = Vector3.new(position.X, position.Y * 2, 0).Unit
			local frame = CFrame.lookAt(position, position + normal) * CFrame.Angles(0, 0, 0.6)
			piece(
				rig,
				"Spot",
				"Oval",
				Vector3.new(0.2, 0.16, 0.06),
				frame,
				options.spots,
				if options.crystal then Enum.Material.Neon else nil
			)
			-- Rosetas: centro más oscuro que el pelaje dentro de cada mancha.
			if not options.crystal then
				piece(
					rig,
					"SpotCenter",
					"Oval",
					Vector3.new(0.11, 0.08, 0.06),
					frame * CFrame.new(0, 0, -0.015),
					coat:Lerp(Color3.fromRGB(170, 100, 40), 0.5)
				)
			end
		end
	end
	if options.crystal then
		for _, part in rig.model:GetChildren() do
			if part:IsA("BasePart") and part.Material == Enum.Material.Glass then
				part.Transparency = 0.25
			end
		end
	end
end

local BIRD_HEAD = Vector3.new(0, 0.68, -0.42)

-- Cuerpo y cabeza de ave, y patas recogidas bajo el cuerpo.
local function bird(rig: Rig, color: Color3, feet: Color3)
	piece(rig, "Body", "Oval", Vector3.new(0.85, 1.05, 1.25), CFrame.Angles(0.35, 0, 0), color)
	piece(rig, "Head", "Ball", Vector3.one * 0.72, CFrame.new(BIRD_HEAD), color)
	for _, side in { -1, 1 } do
		piece(rig, "Foot", "Oval", Vector3.new(0.16, 0.1, 0.3), CFrame.new(side * 0.18, -0.56, -0.05), feet)
	end
end

-- Parche de piel o plumas alrededor del ojo, pegado a la cabeza de ave (detrás del ojo).
local function eyePatch(rig: Rig, eyeCenter: Vector3, size: Vector3, color: Color3)
	local direction = (eyeCenter - BIRD_HEAD).Unit
	patch(rig, "EyePatch", size, BIRD_HEAD + direction * 0.37, direction, color)
end

local builders: { [string]: (rig: Rig, color: Color3) -> Motion } = {
	-- Tucán: negro, pecho amarillo y un pico enorme naranja con punta roja.
	Tucan = function(rig, color)
		bird(rig, color, Color3.fromRGB(90, 110, 170))
		-- Piel azul alrededor de los ojos, cresta del pico y rabadilla blanca.
		for _, side in { -1, 1 } do
			eyePatch(
				rig,
				Vector3.new(side * 0.23, 0.78, -0.62),
				Vector3.new(0.32, 0.3, 0.06),
				Color3.fromRGB(70, 160, 230)
			)
		end
		piece(
			rig,
			"BeakRidge",
			"Oval",
			Vector3.new(0.12, 0.07, 1.2),
			CFrame.new(0, 0.8, -1.33) * CFrame.Angles(-0.12, 0, 0),
			Color3.fromRGB(200, 220, 70)
		)
		piece(rig, "Rump", "Oval", Vector3.new(0.4, 0.18, 0.3), CFrame.new(0, -0.2, 0.62), WHITE)
		piece(
			rig,
			"Throat",
			"Oval",
			Vector3.new(0.62, 0.6, 0.35),
			CFrame.new(0, 0.3, -0.55),
			Color3.fromRGB(255, 235, 150)
		)
		eyes(rig, Vector3.new(0, 0.78, -0.62), 0.23, 0.2, Color3.fromRGB(40, 90, 200))
		piece(
			rig,
			"BeakBase",
			"Oval",
			Vector3.new(0.42, 0.46, 0.3),
			CFrame.new(0, 0.64, -0.85),
			Color3.fromRGB(170, 210, 60)
		)
		piece(
			rig,
			"Beak",
			"Oval",
			Vector3.new(0.38, 0.42, 1.3),
			CFrame.new(0, 0.6, -1.35) * CFrame.Angles(-0.12, 0, 0),
			Color3.fromRGB(255, 150, 30)
		)
		piece(
			rig,
			"BeakTip",
			"Oval",
			Vector3.new(0.24, 0.28, 0.35),
			CFrame.new(0, 0.5, -1.95),
			Color3.fromRGB(220, 40, 30)
		)
		for _, side in { -1, 1 } do
			wing(rig, side, Vector3.new(side * 0.35, 0.2, 0.1), {
				{ size = Vector3.new(1.1, 0.12, 0.6), offset = Vector3.new(0.5, 0, 0), color = color },
				-- Puntas de las plumas con reflejo azulado.
				{
					size = Vector3.new(0.7, 0.1, 0.42),
					offset = Vector3.new(1.0, 0.01, 0.08),
					color = Color3.fromRGB(45, 45, 70),
				},
			}, 0.7, 14)
		end
		piece(
			rig,
			"Tail",
			"Block",
			Vector3.new(0.45, 0.1, 0.8),
			CFrame.new(0, -0.35, 0.85) * CFrame.Angles(0.45, 0, 0),
			color
		)
		piece(
			rig,
			"UnderTail",
			"Oval",
			Vector3.new(0.35, 0.2, 0.3),
			CFrame.new(0, -0.45, 0.45),
			Color3.fromRGB(220, 40, 30)
		)
		return "Fly"
	end,

	-- Tortuga: caparazón con placas, cabeza que mira a los lados y patitas.
	Tortuga = function(rig, color)
		local skin = Color3.fromRGB(150, 170, 100)
		local plate = color:Lerp(Color3.fromRGB(200, 180, 90), 0.35)
		piece(rig, "Shell", "Oval", Vector3.new(1.7, 1.1, 2.0), CFrame.new(0, 0.15, 0), color)
		piece(rig, "Rim", "Oval", Vector3.new(1.95, 0.3, 2.25), CFrame.new(0, -0.15, 0), color:Lerp(BLACK, 0.3))
		for _, position in
			{
				Vector3.new(0, 0.67, 0.05),
				Vector3.new(0, 0.6, -0.55),
				Vector3.new(0, 0.6, 0.55),
				Vector3.new(-0.55, 0.56, 0),
				Vector3.new(0.55, 0.56, 0),
			}
		do
			local normal = Vector3.new(position.X / 0.85, (position.Y - 0.15) / 0.55, position.Z).Unit
			piece(rig, "Plate", "Oval", Vector3.new(0.55, 0.5, 0.12), CFrame.lookAt(position, position + normal), plate)
		end
		-- Placas del borde del caparazón, alrededor de todo el contorno.
		for i = 0, 11 do
			local angle = i * math.pi / 6
			local position = Vector3.new(math.cos(angle) * 0.84, -0.07, math.sin(angle) * 0.98)
			patch(
				rig,
				"EdgePlate",
				Vector3.new(0.42, 0.2, 0.12),
				position,
				position * Vector3.new(1, 0, 1),
				plate:Lerp(BLACK, 0.15)
			)
		end
		-- Cabeza con cuello, boca y ojos: todo gira junto, mirando a los lados.
		local headParts: { BasePart } = {
			piece(rig, "Neck", "Oval", Vector3.new(0.38, 0.36, 0.55), CFrame.new(0, 0, -1.0), skin),
			piece(rig, "Head", "Oval", Vector3.new(0.55, 0.5, 0.7), CFrame.new(0, 0.05, -1.3), skin),
			piece(
				rig,
				"Mouth",
				"Oval",
				Vector3.new(0.28, 0.025, 0.1),
				CFrame.new(0, -0.04, -1.6),
				skin:Lerp(BLACK, 0.5)
			),
		}
		for _, side in { -1, 1 } do
			table.insert(
				headParts,
				piece(rig, "Eye", "Ball", Vector3.one * 0.13, CFrame.new(side * 0.2, 0.15, -1.52), BLACK)
			)
			table.insert(
				headParts,
				piece(
					rig,
					"Glint",
					"Ball",
					Vector3.one * 0.045,
					CFrame.new(side * 0.21, 0.19, -1.57),
					WHITE,
					Enum.Material.Neon
				)
			)
		end
		for _, part in headParts do
			joint(rig, part, CFrame.new(0, 0, -1), Vector3.yAxis, 0.3, 1.5, 0, false)
		end
		legs(rig, skin, -0.75, 0.75, 0.72, -0.35, Vector3.new(0.45, 0.45, 0.55), skin:Lerp(BLACK, 0.15))
		piece(
			rig,
			"TailTip",
			"Wedge",
			Vector3.new(0.2, 0.2, 0.35),
			CFrame.new(0, -0.15, 1.2) * CFrame.Angles(0, math.pi, 0),
			skin
		)
		return "Walk"
	end,

	-- Rana dardo: azul con manchas negras y ojos saltones; va a saltos.
	Rana = function(rig, color)
		local dark = color:Lerp(BLACK, 0.3)
		piece(rig, "Body", "Oval", Vector3.new(1.0, 0.75, 1.15), CFrame.Angles(0.25, 0, 0), color)
		for _, position in
			{
				Vector3.new(0.2, 0.33, 0.1),
				Vector3.new(-0.25, 0.3, -0.15),
				Vector3.new(0.05, 0.27, 0.4),
				Vector3.new(-0.2, 0.32, 0.3),
				Vector3.new(0.42, 0.05, -0.1),
				Vector3.new(-0.42, 0.05, 0.15),
			}
		do
			local normal = Vector3.new(position.X, position.Y * 2, position.Z * 0.5).Unit
			piece(rig, "Spot", "Oval", Vector3.new(0.26, 0.2, 0.06), CFrame.lookAt(position, position + normal), BLACK)
		end
		piece(rig, "Throat", "Oval", Vector3.new(0.5, 0.2, 0.32), CFrame.new(0, -0.15, -0.42), color:Lerp(WHITE, 0.35))
		for _, side in { -1, 1 } do
			piece(rig, "EyeBump", "Ball", Vector3.one * 0.38, CFrame.new(side * 0.28, 0.38, -0.38), color)
			piece(rig, "Pupil", "Ball", Vector3.one * 0.22, CFrame.new(side * 0.32, 0.45, -0.5), BLACK)
			piece(
				rig,
				"Glint",
				"Ball",
				Vector3.one * 0.06,
				CFrame.new(side * 0.31, 0.5, -0.6),
				WHITE,
				Enum.Material.Neon
			)
			-- Dedos de las patas delanteras y pie palmeado de las traseras.
			for k = -1, 1 do
				piece(rig, "Toe", "Ball", Vector3.one * 0.09, CFrame.new(side * 0.35 + k * 0.07, -0.46, -0.5), dark)
			end
			piece(
				rig,
				"Foot",
				"Oval",
				Vector3.new(0.28, 0.07, 0.4),
				CFrame.new(side * 0.62, -0.4, 0.62) * CFrame.Angles(0, side * 0.5, 0),
				dark
			)
			piece(
				rig,
				"BackLeg",
				"Oval",
				Vector3.new(0.35, 0.3, 0.85),
				CFrame.new(side * 0.5, -0.25, 0.3) * CFrame.Angles(0, side * 0.35, 0),
				dark
			)
			piece(rig, "FrontLeg", "Oval", Vector3.new(0.2, 0.45, 0.2), CFrame.new(side * 0.35, -0.25, -0.42), dark)
		end
		piece(rig, "Mouth", "Oval", Vector3.new(0.55, 0.05, 0.2), CFrame.new(0, 0.05, -0.58), BLACK)
		return "Hop"
	end,

	-- Guacamaya: roja, alas amarillas y azules, cara blanca y cola larga.
	Guacamaya = function(rig, color)
		local blue = Color3.fromRGB(40, 90, 220)
		bird(rig, color, Color3.fromRGB(70, 70, 75))
		for _, side in { -1, 1 } do
			piece(rig, "Face", "Oval", Vector3.new(0.12, 0.35, 0.35), CFrame.new(side * 0.3, 0.66, -0.55), WHITE)
			-- Líneas de plumitas oscuras sobre la cara blanca.
			for k = 0, 2 do
				piece(
					rig,
					"FaceLine",
					"Block",
					Vector3.new(0.02, 0.025, 0.2),
					CFrame.new(side * 0.365, 0.58 + k * 0.08, -0.55),
					BLACK
				)
			end
			wing(rig, side, Vector3.new(side * 0.35, 0.2, 0.1), {
				{
					size = Vector3.new(0.75, 0.13, 0.65),
					offset = Vector3.new(0.4, 0, 0),
					color = Color3.fromRGB(250, 200, 40),
				},
				-- Franja verde entre el amarillo y el azul.
				{
					size = Vector3.new(0.55, 0.115, 0.55),
					offset = Vector3.new(0.75, 0.005, 0.05),
					color = Color3.fromRGB(60, 170, 80),
				},
				{ size = Vector3.new(0.85, 0.1, 0.55), offset = Vector3.new(1.05, 0, 0.05), color = blue },
			}, 0.7, 12)
			piece(
				rig,
				"TailFeather",
				"Block",
				Vector3.new(0.18, 0.07, 1.3),
				CFrame.new(side * 0.14, -0.42, 1.1) * CFrame.Angles(0.35, side * 0.18, 0),
				color
			)
		end
		eyes(rig, Vector3.new(0, 0.78, -0.62), 0.26, 0.15)
		piece(
			rig,
			"Beak",
			"Oval",
			Vector3.new(0.3, 0.45, 0.4),
			CFrame.new(0, 0.62, -0.85) * CFrame.Angles(-0.4, 0, 0),
			Color3.fromRGB(235, 225, 210)
		)
		piece(rig, "LowerBeak", "Oval", Vector3.new(0.24, 0.2, 0.25), CFrame.new(0, 0.46, -0.75), BLACK)
		piece(
			rig,
			"Tail",
			"Block",
			Vector3.new(0.3, 0.08, 1.6),
			CFrame.new(0, -0.45, 1.2) * CFrame.Angles(0.35, 0, 0),
			color
		)
		piece(
			rig,
			"TailTip",
			"Block",
			Vector3.new(0.2, 0.09, 0.9),
			CFrame.new(0, -0.62, 1.65) * CFrame.Angles(0.35, 0, 0),
			blue
		)
		return "Fly"
	end,

	-- Perezoso: cara clara con antifaz, brazos largos con garras y un hatillo de troncos a la espalda.
	Perezoso = function(rig, color)
		local dark = Color3.fromRGB(60, 40, 30)
		piece(rig, "Body", "Oval", Vector3.new(1.3, 1.4, 1.1), CFrame.new(0, 0, 0), color)
		piece(rig, "Belly", "Oval", Vector3.new(0.9, 1.0, 0.3), CFrame.new(0, -0.05, -0.45), color:Lerp(WHITE, 0.3))
		piece(rig, "Head", "Ball", Vector3.one * 0.95, CFrame.new(0, 0.85, -0.25), color)
		piece(rig, "Face", "Oval", Vector3.new(0.75, 0.6, 0.3), CFrame.new(0, 0.82, -0.62), CREAM)
		for _, side in { -1, 1 } do
			piece(
				rig,
				"Mask",
				"Oval",
				Vector3.new(0.35, 0.14, 0.12),
				CFrame.new(side * 0.2, 0.88, -0.74) * CFrame.Angles(0, 0, side * 0.35),
				dark
			)
			piece(rig, "Eye", "Ball", Vector3.one * 0.11, CFrame.new(side * 0.2, 0.89, -0.81), BLACK)
			local hinge = CFrame.new(side * 0.6, 0.45, -0.25)
			local arm = piece(
				rig,
				"Arm",
				"Oval",
				Vector3.new(0.32, 1.1, 0.32),
				CFrame.new(side * 0.72, -0.05, -0.25) * CFrame.Angles(0, 0, side * 0.2),
				color
			)
			local armPhase = if side < 0 then 0 else math.pi
			joint(rig, arm, hinge, Vector3.xAxis, 0.5, 4, armPhase, true)
			-- Tres garras largas en cada mano.
			for k = -1, 1 do
				local claw = piece(
					rig,
					"Claw",
					"Wedge",
					Vector3.new(0.06, 0.32, 0.14),
					CFrame.new(side * 0.83 + k * 0.08, -0.68, -0.3),
					CREAM
				)
				joint(rig, claw, hinge, Vector3.xAxis, 0.5, 4, armPhase, true)
			end
			local leg = piece(rig, "Leg", "Oval", Vector3.new(0.38, 0.6, 0.4), CFrame.new(side * 0.35, -0.75, 0), color)
			joint(
				rig,
				leg,
				CFrame.new(side * 0.35, -0.5, 0),
				Vector3.xAxis,
				0.4,
				4,
				if side < 0 then math.pi else 0,
				true
			)
		end
		piece(rig, "Nose", "Ball", Vector3.one * 0.18, CFrame.new(0, 0.76, -0.8), dark)
		piece(rig, "Smile", "Oval", Vector3.new(0.26, 0.05, 0.05), CFrame.new(0, 0.68, -0.755), dark)
		-- Pelo revuelto en la coronilla.
		for _, position in
			{
				Vector3.new(0, 1.3, -0.15),
				Vector3.new(0.22, 1.24, -0.05),
				Vector3.new(-0.22, 1.24, -0.05),
				Vector3.new(0.12, 1.26, 0.15),
				Vector3.new(-0.12, 1.27, 0.12),
			}
		do
			piece(rig, "Tuft", "Oval", Vector3.new(0.28, 0.22, 0.28), CFrame.new(position), color:Lerp(BLACK, 0.15))
		end
		-- Manchas de alga verdosa en el pelo, como los perezosos de verdad.
		local algae = color:Lerp(Color3.fromRGB(110, 150, 80), 0.5)
		for _, direction in { Vector3.new(0.8, 0.4, 0.3), Vector3.new(-0.7, 0.1, 0.5), Vector3.new(0.5, -0.5, 0.6) } do
			-- Punto de la superficie del cuerpo (óvalo de semiejes 0,65 × 0,7 × 0,55) en esa dirección.
			local onBody = direction
				/ math.sqrt((direction.X / 0.65) ^ 2 + (direction.Y / 0.7) ^ 2 + (direction.Z / 0.55) ^ 2)
			local normal = Vector3.new(onBody.X / 0.4225, onBody.Y / 0.49, onBody.Z / 0.3025)
			patch(rig, "Algae", Vector3.new(0.4, 0.3, 0.05), onBody, normal, algae)
		end
		local wood = Color3.fromRGB(120, 85, 50)
		for _, position in { Vector3.new(0, 0.05, 0.68), Vector3.new(0, 0.42, 0.68), Vector3.new(0, 0.24, 0.98) } do
			piece(rig, "Log", "Cylinder", Vector3.new(1.5, 0.36, 0.36), CFrame.new(position), wood, Enum.Material.Wood)
		end
		piece(
			rig,
			"Rope",
			"Block",
			Vector3.new(0.12, 0.85, 0.75),
			CFrame.new(0, 0.25, 0.8),
			CREAM,
			Enum.Material.Fabric
		)
		return "Walk"
	end,

	-- Jaguarundí: felino esbelto, liso y oscuro.
	Jaguarundi = function(rig, color)
		cat(rig, color, { eyeColor = Color3.fromRGB(200, 170, 40), earSize = 0.3 })
		return "Walk"
	end,

	-- Colibrí: diminuto, verde con garganta magenta, pico largo y alas que zumban.
	Colibri = function(rig, color)
		piece(rig, "Body", "Oval", Vector3.new(0.55, 0.6, 1.0), CFrame.Angles(0.6, 0, 0), color, Enum.Material.Metal)
		piece(
			rig,
			"Throat",
			"Oval",
			Vector3.new(0.42, 0.35, 0.3),
			CFrame.new(0, 0.2, -0.38),
			Color3.fromRGB(220, 40, 120)
		)
		piece(rig, "Head", "Ball", Vector3.one * 0.5, CFrame.new(0, 0.45, -0.35), color, Enum.Material.Metal)
		-- Coronilla tornasolada y una mota blanca detrás de cada ojo.
		piece(
			rig,
			"Crown",
			"Oval",
			Vector3.new(0.38, 0.14, 0.38),
			CFrame.new(0, 0.66, -0.36),
			color:Lerp(Color3.fromRGB(120, 255, 220), 0.35),
			Enum.Material.Metal
		)
		for _, side in { -1, 1 } do
			piece(rig, "EyeDot", "Ball", Vector3.one * 0.07, CFrame.new(side * 0.21, 0.55, -0.4), WHITE)
			piece(rig, "Foot", "Ball", Vector3.one * 0.08, CFrame.new(side * 0.08, -0.35, -0.1), BLACK)
			piece(
				rig,
				"TailFeather",
				"Block",
				Vector3.new(0.18, 0.05, 0.45),
				CFrame.new(side * 0.12, -0.36, 0.55) * CFrame.Angles(0.6, side * 0.35, 0),
				color:Lerp(BLACK, 0.4)
			)
		end
		eyes(rig, Vector3.new(0, 0.52, -0.55), 0.15, 0.12)
		piece(
			rig,
			"Beak",
			"Cylinder",
			Vector3.new(0.9, 0.07, 0.07),
			CFrame.new(0, 0.45, -1.0) * CFrame.Angles(0, math.pi / 2, 0),
			BLACK
		)
		for _, side in { -1, 1 } do
			wing(rig, side, Vector3.new(side * 0.15, 0.3, 0.05), {
				{
					size = Vector3.new(0.9, 0.06, 0.35),
					offset = Vector3.new(0.45, 0, 0),
					color = color:Lerp(WHITE, 0.4),
				},
				{ size = Vector3.new(0.55, 0.05, 0.22), offset = Vector3.new(0.28, 0.02, -0.06), color = color },
			}, 0.9, 45)
		end
		piece(
			rig,
			"Tail",
			"Block",
			Vector3.new(0.3, 0.06, 0.5),
			CFrame.new(0, -0.35, 0.55) * CFrame.Angles(0.6, 0, 0),
			color:Lerp(BLACK, 0.4)
		)
		return "Hover"
	end,

	-- Ocelote: felino dorado con manchas negras.
	Ocelote = function(rig, color)
		cat(rig, color, { spots = BLACK, eyeColor = Color3.fromRGB(120, 200, 60), earSize = 0.38 })
		return "Walk"
	end,

	-- Mono X-7: chimpancé del laboratorio, de pelo azul eléctrico con calvas cosidas, agachado sobre
	-- los nudillos. Casco de astronauta oxidado con visor de espejo, antena de espiral que brilla y
	-- tubos anillados que van de las sienes a la mochila del suero.
	MonoX7 = function(rig, color)
		local fur = Color3.fromRGB(35, 115, 215)
		local furLight = fur:Lerp(Color3.fromRGB(150, 220, 255), 0.45)
		local furDark = fur:Lerp(BLACK, 0.3)
		local hands = Color3.fromRGB(85, 72, 78)
		local scar = Color3.fromRGB(200, 125, 125)
		local stitch = Color3.fromRGB(70, 30, 40)
		local shell = Color3.fromRGB(200, 185, 152)
		local rust = Color3.fromRGB(175, 90, 40)
		local copper = Color3.fromRGB(185, 115, 65)
		local metal = Color3.fromRGB(95, 100, 112)
		local hose = Color3.fromRGB(60, 64, 74)

		-- Tronco inclinado hacia delante: "back" es el marco del tronco (su +Z es la espalda).
		local lean = -0.55
		local back = CFrame.new(0, 0.05, 0) * CFrame.Angles(lean, 0, 0)
		piece(rig, "Body", "Oval", Vector3.new(1.15, 1.25, 1.0), back, fur, Enum.Material.Fabric)
		piece(rig, "Hips", "Oval", Vector3.new(1.0, 0.85, 0.9), CFrame.new(0, -0.3, 0.4), fur, Enum.Material.Fabric)
		piece(rig, "Belly", "Oval", Vector3.new(0.75, 0.85, 0.3), back * CFrame.new(0, -0.1, -0.38), furLight)

		-- Casco grande de caricatura; la cara no se ve: la tapa un visor de espejo.
		local head = Vector3.new(0, 1.0, -0.5)
		piece(rig, "Helmet", "Ball", Vector3.one * 1.36, CFrame.new(head), shell)
		local facing = CFrame.Angles(0, math.pi / 2, 0)
		piece(
			rig,
			"VisorRim",
			"Cylinder",
			Vector3.new(0.14, 1.1, 1.1),
			CFrame.new(head + Vector3.new(0, 0, -0.5)) * facing,
			copper
		)
		-- Visor: cúpula que sobresale del aro, oscura y con reflejo de espejo, y un brillo blanco en
		-- diagonal arriba a un lado, como en los cascos de dibujos animados.
		local visorCenter = head + Vector3.new(0, 0, -0.56)
		local visorSize = Vector3.new(0.98, 0.94, 0.44)
		local visor = piece(rig, "Visor", "Oval", visorSize, CFrame.new(visorCenter), Color3.fromRGB(25, 35, 55))
		visor.Reflectance = 0.6
		for _, shine in { { -0.22, 0.17, Vector3.new(0.09, 0.3, 0.04) }, { -0.05, 0.3, Vector3.new(0.07, 0.07, 0.04) } } do
			-- Punto de la superficie de la cúpula y su normal (elipsoide de semiejes visorSize / 2).
			local axes = visorSize / 2
			local x, y = shine[1], shine[2]
			local z = -axes.Z * math.sqrt(1 - (x / axes.X) ^ 2 - (y / axes.Y) ^ 2)
			local normal = Vector3.new(x / axes.X ^ 2, y / axes.Y ^ 2, z / axes.Z ^ 2).Unit
			local position = visorCenter + Vector3.new(x, y, z) + normal * 0.01
			local glint = piece(
				rig,
				"VisorShine",
				"Oval",
				shine[3],
				CFrame.lookAt(position, position + normal) * CFrame.Angles(0, 0, -0.6),
				WHITE
			)
			glint.Transparency = 0.15
		end
		-- Remaches del aro de la abertura.
		local rivets = 8
		for i = 1, rivets do
			local angle = (i - 0.5) * 2 * math.pi / rivets
			local position = head + Vector3.new(math.cos(angle) * 0.51, math.sin(angle) * 0.51, -0.575)
			piece(rig, "Rivet", "Ball", Vector3.one * 0.07, CFrame.new(position), metal)
		end

		-- Casco: cresta de delante atrás, cuello de cobre, discos en las sienes y manchas de óxido.
		piece(rig, "Crest", "Cylinder", Vector3.new(0.14, 1.42, 1.42), CFrame.new(head), shell:Lerp(metal, 0.35))
		piece(
			rig,
			"Collar",
			"Cylinder",
			Vector3.new(0.18, 1.0, 1.0),
			CFrame.new(head + Vector3.new(0, -0.6, 0.05)) * UPRIGHT,
			copper
		)
		for _, side in { -1, 1 } do
			local temple = head + Vector3.new(side * 0.66, -0.05, 0.08)
			piece(rig, "EarDisc", "Cylinder", Vector3.new(0.14, 0.44, 0.44), CFrame.new(temple), metal)
			piece(
				rig,
				"EarRing",
				"Cylinder",
				Vector3.new(0.16, 0.3, 0.3),
				CFrame.new(temple + Vector3.new(side * 0.02, 0, 0)),
				copper
			)
			piece(
				rig,
				"EarKnob",
				"Ball",
				Vector3.one * 0.14,
				CFrame.new(temple + Vector3.new(side * 0.08, 0, 0)),
				metal
			)
		end
		-- Óxido: cada mancha son dos óvalos girados y desplazados, para que no parezcan lunares.
		-- Óxido: cada mancha son dos óvalos girados y desplazados, de tamaños distintos, para que no
		-- parezcan lunares.
		for i, spot in
			{
				{ Vector3.new(0.6, 0.5, -0.3), 1.2 },
				{ Vector3.new(-0.6, 0.3, 0.45), 0.8 },
				{ Vector3.new(0.55, -0.35, 0.5), 1.0 },
				{ Vector3.new(0, 0.35, 0.95), 1.35 },
				{ Vector3.new(-0.55, -0.45, -0.25), 0.7 },
			}
		do
			local normal = spot[1].Unit
			local center = head + normal * 0.675
			local frame = CFrame.lookAt(center, center + normal) * CFrame.Angles(0, 0, i * 1.3)
			piece(rig, "Rust", "Oval", Vector3.new(0.36 * spot[2], 0.2 * spot[2], 0.05), frame, rust)
			piece(
				rig,
				"Rust",
				"Oval",
				Vector3.new(0.2 * spot[2], 0.15 * spot[2], 0.05),
				frame * CFrame.new(0.14 * spot[2], -0.06 * spot[2], -0.006),
				rust:Lerp(shell, 0.4)
			)
		end
		-- Placa con su número en la frente, a un lado de la cresta.
		local badgeNormal = Vector3.new(0.4, 0.72, -0.56).Unit
		local badge = piece(
			rig,
			"Badge",
			"Block",
			Vector3.new(0.34, 0.15, 0.04),
			CFrame.lookAt(head + badgeNormal * 0.69, head + badgeNormal * 2),
			metal
		)
		local label = Instance.new("SurfaceGui")
		label.Face = Enum.NormalId.Front
		label.CanvasSize = Vector2.new(68, 30)
		label.LightInfluence = 0
		label.Parent = badge
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = "X-7"
		text.TextScaled = true
		text.Font = Enum.Font.BuilderSansBold
		text.TextColor3 = color
		text.Parent = label

		-- Antena: base, espiral de anillos que se estrecha y punta que brilla; se balancea un poco.
		local top = head + Vector3.new(0, 0.66, 0)
		local antenna: { BasePart } = {
			piece(rig, "AntennaBase", "Cylinder", Vector3.new(0.14, 0.34, 0.34), CFrame.new(top) * UPRIGHT, copper),
		}
		local rings = 5
		for i = 1, rings do
			local width = 0.3 - (i - 1) * 0.05
			local ringColor = if i % 2 == 1 then shell:Lerp(metal, 0.3) else metal
			table.insert(
				antenna,
				piece(
					rig,
					"AntennaRing",
					"Cylinder",
					Vector3.new(0.1, width, width),
					CFrame.new(top + Vector3.new(0, 0.04 + i * 0.08, 0)) * UPRIGHT,
					ringColor
				)
			)
		end
		local tip = piece(
			rig,
			"AntennaTip",
			"Ball",
			Vector3.one * 0.2,
			CFrame.new(top + Vector3.new(0, 0.58, 0)),
			color,
			Enum.Material.Neon
		)
		table.insert(antenna, tip)
		table.insert(
			antenna,
			piece(
				rig,
				"AntennaGlow",
				"Ball",
				Vector3.one * 0.32,
				CFrame.new(top + Vector3.new(0, 0.58, 0)),
				color,
				Enum.Material.Neon
			)
		)
		antenna[#antenna].Transparency = 0.6
		for _, part in antenna do
			joint(rig, part, CFrame.new(top), Vector3.zAxis, 0.08, 3, 0, false)
		end
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 5
		light.Brightness = 1
		light.Parent = tip

		-- Mochila con el vial de suero y tubos anillados desde los discos de las sienes.
		piece(rig, "Pack", "Block", Vector3.new(0.62, 0.62, 0.3), back * CFrame.new(0, 0.1, 0.6), metal)
		local vialFrame = back * CFrame.new(0, 0.1, 0.8) * UPRIGHT
		local vial = piece(
			rig,
			"Vial",
			"Cylinder",
			Vector3.new(0.5, 0.28, 0.28),
			vialFrame,
			Color3.fromRGB(200, 240, 255),
			Enum.Material.Glass
		)
		vial.Transparency = 0.5
		local serum = piece(rig, "Serum", "Cylinder", Vector3.new(0.42, 0.2, 0.2), vialFrame, color, Enum.Material.Neon)
		for _, y in { -0.27, 0.27 } do
			piece(rig, "VialCap", "Cylinder", Vector3.new(0.08, 0.32, 0.32), vialFrame * CFrame.new(y, 0, 0), copper)
		end
		local glow = Instance.new("PointLight")
		glow.Color = color
		glow.Range = 6
		glow.Brightness = 1
		glow.Parent = serum
		-- Cada tubo es una curva de bolas alternas, gruesas y finas, que parece un tubo anillado.
		local segments = 14
		for _, side in { -1, 1 } do
			local from = head + Vector3.new(side * 0.62, -0.2, 0.22)
			local to = (back * CFrame.new(side * 0.36, 0.2, 0.6)).Position
			local control = Vector3.new(side * 1.05, 0.75, 0.55)
			for i = 0, segments do
				local t = i / segments
				local position = from:Lerp(control, t):Lerp(control:Lerp(to, t), t)
				local thick = i % 2 == 0
				piece(
					rig,
					"Hose",
					"Ball",
					Vector3.one * (if thick then 0.17 else 0.14),
					CFrame.new(position),
					if thick then metal else hose
				)
			end
		end
		-- Chispas de energía que saltan junto a la mochila.
		for _, side in { -1, 1 } do
			local spark = back * CFrame.new(side * 0.45, 0.45, 0.55)
			for k = 0, 2 do
				local bolt = piece(
					rig,
					"Spark",
					"Block",
					Vector3.new(0.04, 0.18, 0.04),
					spark
						* CFrame.new(side * k * 0.06, k * 0.14, 0)
						* CFrame.Angles(0, 0, side * (if k % 2 == 0 then 0.6 else -0.6)),
					color,
					Enum.Material.Neon
				)
				bolt.Transparency = 0.15
			end
		end

		-- Aura de energía: chispas azules que salen del cuerpo (la nube eléctrica de la foto).
		local body = rig.model:FindFirstChild("Body")
		if body then
			local aura = Instance.new("ParticleEmitter")
			aura.Color = ColorSequence.new(color)
			aura.LightEmission = 1
			aura.Rate = 6
			aura.Lifetime = NumberRange.new(0.5, 0.9)
			aura.Speed = NumberRange.new(0.6, 1.2)
			aura.SpreadAngle = Vector2.new(180, 180)
			aura.Size = NumberSequence.new(0.18 * rig.scale, 0)
			aura.Transparency = NumberSequence.new(0.2, 1)
			aura.Parent = body
		end

		-- Calvas cosidas en el pelo (de la piel enferma de la foto, en versión de dibujo).
		local function scarPatch(position: Vector3, normal: Vector3, size: Vector3, stitches: number): { BasePart }
			local frame = CFrame.lookAt(position, position + normal.Unit)
			local parts = { piece(rig, "Scar", "Oval", size, frame, scar) }
			for k = 1, stitches do
				local x = (k - (stitches + 1) / 2) * size.X / (stitches + 1)
				table.insert(
					parts,
					piece(
						rig,
						"Stitch",
						"Block",
						Vector3.new(0.025, size.Y * 1.1, 0.03),
						frame * CFrame.new(x, 0, -size.Z / 2),
						stitch
					)
				)
			end
			table.insert(
				parts,
				piece(
					rig,
					"Stitch",
					"Block",
					Vector3.new(size.X * 0.8, 0.025, 0.03),
					frame * CFrame.new(0, 0, -size.Z / 2),
					stitch
				)
			)
			return parts
		end
		scarPatch(
			(back * CFrame.new(0.3, 0.25, -0.42)).Position,
			back.LookVector + Vector3.new(0.4, 0, 0),
			Vector3.new(0.34, 0.26, 0.05),
			3
		)
		scarPatch(
			(back * CFrame.new(-0.52, -0.15, 0.1)).Position,
			Vector3.new(-1, 0, 0.2),
			Vector3.new(0.36, 0.28, 0.05),
			3
		)
		scarPatch(Vector3.new(0.32, -0.05, 0.75), Vector3.new(0.5, 0.2, 1), Vector3.new(0.3, 0.24, 0.05), 3)

		-- Brazos largos que llegan al suelo delante (anda sobre los nudillos) y patas flexionadas.
		for _, side in { -1, 1 } do
			local shoulder = Vector3.new(side * 0.58, 0.32, -0.35)
			local elbow = Vector3.new(side * 0.76, -0.35, -0.6)
			local wrist = Vector3.new(side * 0.72, -0.82, -0.78)
			local arm: { BasePart } = {
				piece(rig, "Shoulder", "Ball", Vector3.one * 0.5, CFrame.new(shoulder), fur, Enum.Material.Fabric),
				capsule(rig, "UpperArm", shoulder, elbow, 0.36, fur),
				piece(rig, "Elbow", "Ball", Vector3.one * 0.36, CFrame.new(elbow), fur, Enum.Material.Fabric),
				piece(
					rig,
					"ElbowTuft",
					"Oval",
					Vector3.new(0.2, 0.32, 0.18),
					CFrame.new(elbow + Vector3.new(side * 0.08, 0.02, 0.17)) * CFrame.Angles(0.6, 0, 0),
					furDark
				),
				capsule(rig, "Forearm", elbow, wrist, 0.38, fur),
				piece(rig, "Hand", "Oval", Vector3.new(0.36, 0.22, 0.42), CFrame.new(side * 0.72, -0.9, -0.86), hands),
				piece(
					rig,
					"Thumb",
					"Oval",
					Vector3.new(0.1, 0.1, 0.18),
					CFrame.new(side * 0.56, -0.93, -0.92) * CFrame.Angles(0, side * 0.5, 0),
					hands
				),
			}
			for k = -1, 1 do
				table.insert(
					arm,
					piece(
						rig,
						"Knuckle",
						"Ball",
						Vector3.one * 0.13,
						CFrame.new(side * 0.74 + k * 0.1, -0.93, -1.05),
						hands
					)
				)
			end
			if side == 1 then
				local onArm = elbow:Lerp(wrist, 0.45) + Vector3.new(0.17, 0, -0.03)
				for _, part in scarPatch(onArm, Vector3.new(1, 0, -0.2), Vector3.new(0.22, 0.3, 0.05), 2) do
					table.insert(arm, part)
				end
			end
			for _, part in arm do
				joint(rig, part, CFrame.new(shoulder), Vector3.xAxis, 0.35, 8, if side < 0 then 0 else math.pi, true)
			end

			local hip = Vector3.new(side * 0.4, -0.35, 0.45)
			local knee = Vector3.new(side * 0.64, -0.3, 0.02)
			local ankle = Vector3.new(side * 0.56, -0.82, 0.32)
			local leg: { BasePart } = {
				capsule(rig, "Thigh", hip, knee, 0.44, fur),
				piece(rig, "Knee", "Ball", Vector3.one * 0.38, CFrame.new(knee), fur, Enum.Material.Fabric),
				capsule(rig, "Shin", knee, ankle, 0.34, fur),
				piece(rig, "Foot", "Oval", Vector3.new(0.3, 0.14, 0.52), CFrame.new(side * 0.56, -0.93, 0.18), hands),
			}
			for k = 0, 2 do
				table.insert(
					leg,
					piece(
						rig,
						"Toe",
						"Ball",
						Vector3.one * 0.12,
						CFrame.new(side * (0.62 - k * 0.09), -0.94, -0.1),
						hands
					)
				)
			end
			table.insert(
				leg,
				piece(
					rig,
					"BigToe",
					"Oval",
					Vector3.new(0.12, 0.11, 0.2),
					CFrame.new(side * 0.4, -0.94, 0.0) * CFrame.Angles(0, -side * 0.5, 0),
					hands
				)
			)
			if side == -1 then
				local onThigh = hip:Lerp(knee, 0.5) + Vector3.new(-0.2, 0.08, 0)
				for _, part in scarPatch(onThigh, Vector3.new(-1, 0.4, 0), Vector3.new(0.3, 0.24, 0.05), 3) do
					table.insert(leg, part)
				end
			end
			for _, part in leg do
				joint(rig, part, CFrame.new(hip), Vector3.xAxis, 0.35, 8, if side < 0 then math.pi else 0, true)
			end
			-- Mechones de pelo erizado en hombros y caderas (le dan el aire de bicho de laboratorio).
			piece(
				rig,
				"Tuft",
				"Oval",
				Vector3.new(0.22, 0.34, 0.2),
				CFrame.new(side * 0.55, 0.6, -0.15) * CFrame.Angles(0.3, 0, -side * 0.5),
				furDark
			)
			piece(
				rig,
				"Tuft",
				"Oval",
				Vector3.new(0.22, 0.3, 0.2),
				CFrame.new(side * 0.42, 0.05, 0.75) * CFrame.Angles(0.6, 0, -side * 0.4),
				furDark
			)
		end
		return "Walk"
	end,

	-- Jaguar de cristal: felino translúcido con manchas que brillan y destellos.
	JaguarCristal = function(rig, color)
		local options: CatOptions = {
			spots = Color3.fromRGB(80, 200, 255),
			crystal = true,
			eyeColor = Color3.fromRGB(200, 255, 255),
			earSize = 0.36,
		}
		cat(rig, color, options)
		-- Cristales que le salen del lomo, inclinados hacia atrás.
		for i, z in { -0.55, -0.15, 0.25, 0.6 } do
			local height = 0.28 + (i % 2) * 0.14
			local shard = piece(
				rig,
				"Shard",
				"Wedge",
				Vector3.new(0.1, height, 0.28),
				CFrame.new(0, 0.36 + height / 2, z),
				Color3.fromRGB(80, 200, 255),
				Enum.Material.Neon
			)
			shard.Transparency = 0.2
		end
		local body = rig.model:FindFirstChild("Body")
		if body then
			local glow = Instance.new("PointLight")
			glow.Color = color
			glow.Range = 10
			glow.Brightness = 1.5
			glow.Parent = body
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = color
			sparkles.Parent = body
		end
		return "Walk"
	end,
}

function PetModels.build(petId: string): Model?
	local pet = Pets[petId]
	local builder = builders[petId]
	if not (pet and builder) then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = `Mascota_{petId}`
	local rig: Rig = { model = model, scale = pet.size, joints = {} }
	local root = piece(rig, "Root", "Block", Vector3.one * 0.2, CFrame.identity, WHITE)
	root.Transparency = 1
	model.PrimaryPart = root
	local motion = builder(rig, pet.color)
	local box, size = model:GetBoundingBox()
	model:SetAttribute("Motion", motion)
	model:SetAttribute("Height", -(box.Position.Y - size.Y / 2))
	rigs[model] = rig.joints
	model.Destroying:Connect(function()
		rigs[model] = nil
	end)
	return model
end

-- Mueve las partes animadas según el tiempo; "moving" (0 a 1) indica cuánto anda el dueño.
function PetModels.animate(model: Model, time: number, moving: number)
	local joints = rigs[model]
	if not joints then
		return
	end
	local pivot = model:GetPivot()
	for _, item in joints do
		local factor = if item.gait then moving else 1
		local angle = math.sin(time * item.speed + item.phase) * item.amplitude * factor
		item.part.CFrame = pivot * item.hinge * CFrame.fromAxisAngle(item.axis, angle) * item.offset
	end
end

return PetModels
