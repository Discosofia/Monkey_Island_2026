--!strict
-- Modelos provisionales (greybox) de los monos, articulados para poder animarlos (MonkeyAnimator).
-- Todas las especies comparten las mismas piezas animables y articulaciones:
--   HumanoidRootPart ─RootJoint→ Torso
--   Torso ─Neck→ Head
--   Torso ─Right/Left Shoulder→ Right/Left Arm
--   Torso ─Right/Left Hip→ Right/Left Leg
--   Torso ─TailJoint→ Tail
-- Lo demás (cara, ojos, orejas, manos…) va soldado a una de ellas y se mueve con ella.
-- Las animaciones se enlazan por el nombre de las piezas: si cambias un nombre, rehaz las animaciones.
-- Cada especie tiene su propio constructor (BUILDERS); una especie nueva sin él usa el genérico.
-- Las especies en estilo voxel (VOXEL_SPECS: gorila, tití, mono ardilla, capuchino) ya no tienen
-- constructor redondo: su cuerpo y sus pivotes están en VoxelSpecs/<Especie>.
-- Los simios (gorila, chimpancé, orangután, gibón) no tienen cola. Los jefes añaden sus detalles (BOSS_EXTRAS),
-- y algunas especies se construyen con más detalle cuando son un jefe (rig.boss).
-- Cada especie se construye una vez como plantilla y los monos son copias (MonkeyModels.spawn).
-- El Humanoid lo mueve como a un personaje.

local GeometryService = game:GetService("GeometryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)

-- Las posiciones de los constructores son respecto a la raíz, a escala 1, con la cara hacia -Z.
-- La raíz está a rootHeight sobre el suelo: con escala 1, el suelo queda en Y = -1.9.
-- "boss": lo construye un jefe; algunas especies le dan más detalle.
-- "voxel": el cuerpo es de bloques (voxelMonkey) y los adornos del jefe vienen en bloques en su spec.
type Rig = { model: Model, root: BasePart, scale: number, boss: boolean, voxel: boolean }

-- "Spike": pirámide (CornerWedgePart) con la punta sobre la esquina -X +Z de arriba; sirve para cristales.
type Shape = "Block" | "Ball" | "Oval" | "Cylinder" | "Spike"

local MonkeyModels = {}

local EYE_COLOR = Color3.fromRGB(20, 15, 10)
local EYE_WHITE = Color3.fromRGB(245, 240, 225)
local GROUND = -1.9 -- altura del suelo respecto a la raíz, a escala 1

local templates: { [string]: Model } = {}
local bossTemplates: { [string]: Model } = {}

local function piece(
	rig: Rig,
	name: string,
	shape: Shape,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	local part: BasePart
	if shape == "Spike" then
		part = Instance.new("CornerWedgePart")
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
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.Massless = true
	part.Parent = rig.model
	return part
end

local function place(rig: Rig, part: BasePart, rest: CFrame)
	part.CFrame = rig.root.CFrame * CFrame.new(rest.Position * rig.scale) * rest.Rotation
end

-- Articula "part1" a "part0", las dos ya colocadas. Gira sobre "pivot" (hombro, cadera…) con los
-- ejes del modelo: girar en X balancea adelante/atrás, en Y gira a los lados y en Z inclina de costado.
local function attach(rig: Rig, part0: BasePart, part1: BasePart, name: string, pivot: Vector3)
	local pivotFrame = rig.root.CFrame * CFrame.new(pivot * rig.scale)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:ToObjectSpace(pivotFrame)
	motor.C1 = part1.CFrame:ToObjectSpace(pivotFrame)
	motor.Parent = part0
end

-- Como attach, dejando antes "part1" en "rest".
local function joint(rig: Rig, part0: BasePart, part1: BasePart, name: string, rest: CFrame, pivot: Vector3)
	place(rig, part1, rest)
	attach(rig, part0, part1, name, pivot)
end

local function weld(anchor: BasePart, part: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = anchor
	constraint.Part1 = part
	constraint.Parent = part
end

-- Pieza decorativa que sigue a "anchor" sin moverse por su cuenta.
local function glue(rig: Rig, anchor: BasePart, part: BasePart, rest: CFrame)
	place(rig, part, rest)
	weld(anchor, part)
end

local function sideName(side: number): string
	return if side == 1 then "Right" else "Left"
end

-- Pieza de la cara o del cuerpo pegada a "anchor", en coordenadas del modelo.
local function feature(
	rig: Rig,
	anchor: BasePart,
	name: string,
	size: Vector3,
	color: Color3,
	at: CFrame,
	material: Enum.Material?
)
	glue(rig, anchor, piece(rig, name, "Oval", size, color, material), at)
end

local function partNamed(rig: Rig, name: string): BasePart
	return rig.model:FindFirstChild(name) :: BasePart
end

-- Mono genérico: cuerpo encorvado, cabeza adelantada.
local function genericMonkey(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local body = definition.bodyColor
	local face = definition.faceColor
	local torso = piece(rig, "Torso", "Block", Vector3.new(1.8, 1.8, 1.4), body)
	joint(rig, rig.root, torso, "RootJoint", CFrame.identity, Vector3.zero)
	local head = piece(rig, "Head", "Ball", Vector3.one * 1.4, body)
	joint(rig, torso, head, "Neck", CFrame.new(0, 1.1, -0.7), Vector3.new(0, 0.7, -0.5))
	glue(rig, head, piece(rig, "Face", "Block", Vector3.new(0.9, 0.8, 0.25), face), CFrame.new(0, 1.05, -1.3))

	for side = -1, 1, 2 do
		glue(rig, head, piece(rig, "Eye", "Ball", Vector3.one * 0.22, EYE_COLOR), CFrame.new(side * 0.22, 1.2, -1.45))
		glue(rig, head, piece(rig, "Ear", "Ball", Vector3.one * 0.5, face), CFrame.new(side * 0.75, 1.25, -0.6))
		local arm = CFrame.new(side * 1.05, -0.4, -0.3) * CFrame.Angles(math.rad(15), 0, 0)
		joint(
			rig,
			torso,
			piece(rig, `{sideName(side)} Arm`, "Block", Vector3.new(0.45, 1.6, 0.45), body),
			`{sideName(side)} Shoulder`,
			arm,
			(arm * CFrame.new(0, 0.7, 0)).Position
		)
		joint(
			rig,
			torso,
			piece(rig, `{sideName(side)} Leg`, "Block", Vector3.new(0.55, 1, 0.55), body),
			`{sideName(side)} Hip`,
			CFrame.new(side * 0.5, -1.4, 0.2),
			Vector3.new(side * 0.5, -0.95, 0.2)
		)
	end
	local tail = CFrame.new(0, 0.3, 1.6) * CFrame.Angles(math.rad(35), 0, 0)
	joint(
		rig,
		torso,
		piece(rig, "Tail", "Block", Vector3.new(0.3, 0.3, 2.4), body),
		"TailJoint",
		tail,
		(tail * CFrame.new(0, 0, -1.1)).Position
	)
end

local function eyes(rig: Rig, head: BasePart, spread: number, y: number, z: number, diameter: number)
	for side = -1, 1, 2 do
		glue(rig, head, piece(rig, "Eye", "Ball", Vector3.one * diameter, EYE_COLOR), CFrame.new(side * spread, y, z))
	end
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- Chimpancé: pelo negro, largo y mojado que cuelga en mechones de los hombros, los brazos y los
-- flancos; cara clara con el hocico salido, cejas marcadas, orejas grandes, patillas canosas y la
-- barba blanca de la barbilla; manos y pies grandes y oscuros, apoyados en los nudillos.
-- Los jefes (rig.boss) llevan más pelo colgando, nudillos y nariz; el tocado va en BOSS_EXTRAS.
-- bodyColor = pelo, faceColor = piel.
local CHIMP_BEARD = Color3.fromRGB(205, 200, 190)

local function chimpanzee(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local skin = definition.faceColor
	-- Mechones con un brillo más claro, como el pelo mojado de la foto.
	local shag = fur:Lerp(Color3.fromRGB(120, 115, 110), 0.25)
	local paws = darker(skin, 0.62)
	local tilt = CFrame.Angles(math.rad(20), 0, 0)

	local torso = piece(rig, "Torso", "Oval", Vector3.new(1.55, 1.4, 2.1), fur)
	joint(rig, rig.root, torso, "RootJoint", CFrame.new(0, -0.05, 0.35) * tilt, Vector3.new(0, -0.05, 0.35))
	feature(rig, torso, "Shoulders", Vector3.new(2, 1.25, 1.2), fur, CFrame.new(0, 0.3, -0.45))

	local head = piece(rig, "Head", "Ball", Vector3.one * 1.05, fur)
	joint(rig, torso, head, "Neck", CFrame.new(0, 0.62, -1.3), Vector3.new(0, 0.4, -0.85))
	feature(rig, head, "Face", Vector3.new(0.82, 0.85, 0.45), skin, CFrame.new(0, 0.6, -1.68))
	feature(
		rig,
		head,
		"Muzzle",
		Vector3.new(0.64, 0.46, 0.46),
		skin:Lerp(Color3.new(1, 1, 1), 0.08),
		CFrame.new(0, 0.38, -1.86)
	)
	feature(rig, head, "Mouth", Vector3.new(0.42, 0.06, 0.1), darker(skin, 0.55), CFrame.new(0, 0.3, -2.07))
	feature(rig, head, "Brow", Vector3.new(0.88, 0.2, 0.34), darker(skin, 0.25), CFrame.new(0, 0.82, -1.82))
	-- La barba blanca sale de debajo del hocico y apunta hacia abajo y adelante (más larga en el jefe).
	local beardLength = if rig.boss then 0.5 else 0.38
	feature(
		rig,
		head,
		"Beard",
		Vector3.new(0.46, beardLength, 0.32),
		CHIMP_BEARD,
		CFrame.new(0, 0.32 - beardLength / 2, -1.8) * CFrame.Angles(math.rad(20), 0, 0)
	)
	eyes(rig, head, 0.17, 0.66, -1.88, 0.12)
	for side = -1, 1, 2 do
		feature(rig, head, "Ear", Vector3.new(0.14, 0.48, 0.4), skin, CFrame.new(side * 0.56, 0.64, -1.26))
		-- Patillas canosas que enmarcan la cara.
		feature(
			rig,
			head,
			"Sideburn",
			Vector3.new(0.26, 0.55, 0.4),
			fur:Lerp(CHIMP_BEARD, 0.35),
			CFrame.new(side * 0.42, 0.42, -1.58) * CFrame.Angles(0, 0, side * -0.35)
		)
	end

	-- Brazos largos y gruesos apoyados en los nudillos, con el pelo colgando por detrás.
	for side = -1, 1, 2 do
		local x = side * 0.92
		local arm = piece(rig, `{sideName(side)} Arm`, "Oval", Vector3.new(0.62, 2.1, 0.66), fur)
		joint(
			rig,
			torso,
			arm,
			`{sideName(side)} Shoulder`,
			CFrame.new(x, GROUND + 1.05, -0.75),
			Vector3.new(x, -0.16, -0.75)
		)
		feature(rig, arm, "Hand", Vector3.new(0.72, 0.32, 0.88), paws, CFrame.new(x, GROUND + 0.14, -0.86))
		feature(
			rig,
			arm,
			"ArmHair",
			Vector3.new(0.32, 1.15, 0.55),
			shag,
			CFrame.new(side * 1.15, -0.15, -0.55) * CFrame.Angles(0, 0, side * 0.12)
		)

		local legX = side * 0.6
		local leg = piece(rig, `{sideName(side)} Leg`, "Oval", Vector3.new(0.62, 1.45, 0.66), fur)
		joint(
			rig,
			torso,
			leg,
			`{sideName(side)} Hip`,
			CFrame.new(legX, GROUND + 0.725, 1.1),
			Vector3.new(legX, -0.8, 1.1)
		)
		feature(rig, leg, "Foot", Vector3.new(0.72, 0.3, 1.02), paws, CFrame.new(legX, GROUND + 0.13, 0.95))
	end

	if not rig.boss then
		return
	end
	-- Detalle extra del jefe: más pelo mojado colgando, nudillos y nariz.
	feature(rig, torso, "Mane", Vector3.new(1.7, 0.55, 1.5), shag, CFrame.new(0, 0.82, 0.1) * tilt)
	for side = -1, 1, 2 do
		local x = side * 0.92
		glue(
			rig,
			head,
			piece(rig, "Nostril", "Ball", Vector3.one * 0.08, EYE_COLOR),
			CFrame.new(side * 0.08, 0.5, -2.08)
		)
		feature(
			rig,
			torso,
			"SideHair",
			Vector3.new(0.34, 0.9, 1.1),
			shag,
			CFrame.new(side * 0.82, -0.4, 0.3) * CFrame.Angles(0, 0, side * 0.2)
		)
		local arm = partNamed(rig, `{sideName(side)} Arm`)
		for knuckle = -1, 1 do
			glue(
				rig,
				arm,
				piece(rig, "Knuckle", "Ball", Vector3.one * 0.22, paws),
				CFrame.new(x + knuckle * 0.2, GROUND + 0.24, -1.24)
			)
		end
	end
end

-- Orangután, de caricatura: cabeza grande con las almohadillas de las mejillas en forma de corazón
-- alrededor de la cara, ojos grandes, hocico claro y el saco de la garganta; hombros anchos, barriga
-- clara, brazos larguísimos apoyados en los puños con flecos de pelo y piernas cortas.
-- Los jefes (rig.boss) llevan más detalle (mechones, nudillos, antebrazos gruesos, más pelo
-- colgando) y el ceño fruncido; los normales, menos piezas y una cara más amable.
-- bodyColor = pelo, faceColor = piel.
local function orangutan(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local skin = definition.faceColor
	local shag = fur:Lerp(Color3.new(1, 1, 1), 0.12)
	local underFur = darker(fur, 0.18)
	local paws = darker(skin, 0.1)
	local tilt = CFrame.Angles(math.rad(25), 0, 0)

	local torso = piece(rig, "Torso", "Oval", Vector3.new(1.85, 1.7, 2), fur)
	joint(rig, rig.root, torso, "RootJoint", CFrame.new(0, 0.05, 0.3) * tilt, Vector3.new(0, 0.05, 0.3))
	feature(rig, torso, "Shoulders", Vector3.new(2.3, 1.2, 1.25), fur, CFrame.new(0, 0.45, -0.35))
	feature(
		rig,
		torso,
		"Belly",
		Vector3.new(1.35, 1.2, 1.2),
		fur:Lerp(Color3.fromRGB(240, 200, 150), 0.35),
		CFrame.new(0, -0.35, -0.3) * tilt
	)

	local head = piece(rig, "Head", "Ball", Vector3.one * 1.2, fur)
	joint(rig, torso, head, "Neck", CFrame.new(0, 0.75, -1.15), Vector3.new(0, 0.5, -0.7))
	-- Las almohadillas: dos óvalos solapados e inclinados forman un cojín en forma de corazón.
	for side = -1, 1, 2 do
		feature(
			rig,
			head,
			"Flange",
			Vector3.new(1.05, 1.3, 0.5),
			skin:Lerp(fur, 0.5),
			CFrame.new(side * 0.45, 0.78, -1.42) * CFrame.Angles(0, side * 0.3, side * -0.3)
		)
	end
	feature(rig, head, "Face", Vector3.new(0.9, 1.05, 0.45), skin, CFrame.new(0, 0.8, -1.62))
	feature(rig, head, "ThroatSac", Vector3.new(1.15, 0.9, 0.85), skin, CFrame.new(0, 0.12, -1.42))
	local lip = skin:Lerp(Color3.new(1, 1, 1), 0.25)
	feature(rig, head, "Muzzle", Vector3.new(0.8, 0.52, 0.48), lip, CFrame.new(0, 0.48, -1.84))
	feature(rig, head, "Mouth", Vector3.new(0.56, 0.08, 0.14), EYE_COLOR, CFrame.new(0, 0.39, -2.05))
	-- Cejas: fruncidas (las puntas de dentro más bajas) en el jefe; en los demás, altas y con las
	-- puntas de dentro un poco levantadas, que dan cara de curiosidad en vez de enfado.
	local frown = if rig.boss then 0.3 else -0.12
	for side = -1, 1, 2 do
		glue(
			rig,
			head,
			piece(rig, "EyeWhite", "Ball", Vector3.one * 0.34, EYE_WHITE),
			CFrame.new(side * 0.2, 0.95, -1.78)
		)
		glue(rig, head, piece(rig, "Eye", "Ball", Vector3.one * 0.17, EYE_COLOR), CFrame.new(side * 0.19, 0.94, -1.92))
		feature(
			rig,
			head,
			"Brow",
			Vector3.new(0.46, 0.15, 0.25),
			darker(skin, 0.35),
			CFrame.new(side * 0.21, if rig.boss then 1.15 else 1.22, -1.85) * CFrame.Angles(0, 0, side * frown)
		)
	end

	for side = -1, 1, 2 do
		local x = side * 1
		local arm = piece(rig, `{sideName(side)} Arm`, "Oval", Vector3.new(0.62, 2.45, 0.66), fur)
		joint(
			rig,
			torso,
			arm,
			`{sideName(side)} Shoulder`,
			CFrame.new(x, GROUND + 1.225, -0.7),
			Vector3.new(x, 0.26, -0.7)
		)
		feature(rig, arm, "Hand", Vector3.new(0.85, 0.4, 1), paws, CFrame.new(x, GROUND + 0.17, -0.82))
		feature(
			rig,
			arm,
			"ArmHair",
			Vector3.new(0.3, 1.6, 0.7),
			shag,
			CFrame.new(side * 1.24, -0.3, -0.62) * CFrame.Angles(0, 0, side * 0.12)
		)

		local legX = side * 0.62
		local leg = piece(rig, `{sideName(side)} Leg`, "Oval", Vector3.new(0.6, 1.35, 0.64), fur)
		joint(rig, torso, leg, `{sideName(side)} Hip`, CFrame.new(legX, GROUND + 0.675, 1), Vector3.new(legX, -0.81, 1))
		feature(rig, leg, "Foot", Vector3.new(0.75, 0.3, 1.05), paws, CFrame.new(legX, GROUND + 0.13, 0.85))
	end

	if not rig.boss then
		return
	end
	-- Detalle extra del jefe: se ve de cerca y cuesta piezas, así que solo hay uno a la vez.
	feature(rig, torso, "Shag", Vector3.new(1.55, 0.5, 1.7), shag, CFrame.new(0, 0.82, 0.35) * tilt)
	for _, x in { -0.22, 0, 0.22 } do
		feature(
			rig,
			head,
			"Tuft",
			Vector3.new(0.28, 0.5, 0.32),
			shag,
			CFrame.new(x, 1.33 - math.abs(x) * 0.3, -1.12) * CFrame.Angles(0, 0, -x * 1.8)
		)
	end
	for side = -1, 1, 2 do
		local x = side * 1
		glue(
			rig,
			head,
			piece(rig, "Nostril", "Ball", Vector3.one * 0.09, EYE_COLOR),
			CFrame.new(side * 0.09, 0.63, -2.07)
		)
		for _, z in { 0.05, 0.75 } do
			feature(
				rig,
				torso,
				"SideHair",
				Vector3.new(0.38, 0.95, 0.75),
				underFur,
				CFrame.new(side * 0.85, -0.45, z) * CFrame.Angles(0, 0, side * 0.2)
			)
		end

		local arm = partNamed(rig, `{sideName(side)} Arm`)
		feature(rig, arm, "Forearm", Vector3.new(0.8, 1.15, 0.85), fur, CFrame.new(x, -0.95, -0.72))
		feature(rig, arm, "ArmHair", Vector3.new(0.4, 1.2, 0.45), underFur, CFrame.new(x, -0.35, -0.3))
		for knuckle = -1, 1 do
			glue(
				rig,
				arm,
				piece(rig, "Knuckle", "Ball", Vector3.one * 0.25, skin),
				CFrame.new(x + knuckle * 0.23, GROUND + 0.27, -1.22)
			)
		end
		feature(
			rig,
			partNamed(rig, `{sideName(side)} Leg`),
			"ThighHair",
			Vector3.new(0.42, 0.85, 0.7),
			underFur,
			CFrame.new(side * 0.75, -0.75, 1)
		)
	end
end

-- Óvalo estirado entre dos puntos (tramos de brazos, piernas y cola). Devuelve la pieza y su marco
-- para articularla (joint) o pegarla (glue). Sobresale 0,6 × ancho por cada punta para que los
-- tramos se solapen en la articulación y no se vean como cuentas de un collar.
local function capsule(
	rig: Rig,
	name: string,
	from: Vector3,
	to: Vector3,
	width: number,
	color: Color3
): (BasePart, CFrame)
	local direction = to - from
	-- Con un tramo casi vertical, lookAt necesita otra referencia de "arriba".
	local up = if math.abs(direction.Unit.Y) > 0.9 then Vector3.new(0, 0, -1) else Vector3.yAxis
	local part = piece(rig, name, "Oval", Vector3.new(width, width, direction.Magnitude + width * 1.2), color)
	return part, CFrame.lookAt((from + to) / 2, to, up)
end

local function glueCapsule(
	rig: Rig,
	anchor: BasePart,
	name: string,
	from: Vector3,
	to: Vector3,
	width: number,
	color: Color3
)
	local part, at = capsule(rig, name, from, to, width, color)
	glue(rig, anchor, part, at)
end

-- Cabeza esférica de los monos con cola: los rasgos se colocan sobre su superficie para que queden
-- pegados a ella y no flotando delante.
type Sphere = { center: Vector3, radius: number }

-- Mancha pegada a la cabeza en la dirección "direction" (cara, cejas, rayas, hocico). size.Z es lo que
-- sobresale en el centro: por dentro es un óvalo hondo hundido en la cabeza, para que los bordes sigan
-- la curva en vez de despegarse como un plato. size.Y va hacia arriba (o hacia delante, en la
-- coronilla); "spin" la gira sobre sí misma.
local function headPatch(
	rig: Rig,
	head: BasePart,
	sphere: Sphere,
	name: string,
	size: Vector3,
	color: Color3,
	direction: Vector3,
	spin: number?
)
	local normal = direction.Unit
	local depth = size.Z + math.max(size.X, size.Y) * 0.6
	local at = sphere.center + normal * (sphere.radius + size.Z - depth / 2)
	local up = if math.abs(normal.Y) > 0.9 then Vector3.new(0, 0, -1) else Vector3.yAxis
	feature(
		rig,
		head,
		name,
		Vector3.new(size.X, size.Y, depth),
		color,
		CFrame.lookAt(at, at + normal, up) * CFrame.Angles(0, 0, spin or 0)
	)
end

-- Ojos sobre la cabeza: "spread" los abre a los lados y "lift" los sube (proporciones de la dirección);
-- "out" los adelanta, para que asomen sobre una cara (headPatch) que sobresale de la cabeza.
local function sphereEyes(
	rig: Rig,
	head: BasePart,
	sphere: Sphere,
	spread: number,
	lift: number,
	diameter: number,
	out: number,
	color: Color3?
)
	for side = -1, 1, 2 do
		local direction = Vector3.new(side * spread, lift, -1).Unit
		glue(
			rig,
			head,
			piece(rig, "Eye", "Ball", Vector3.one * diameter, color or EYE_COLOR),
			CFrame.new(sphere.center + direction * (sphere.radius + out - diameter * 0.15))
		)
	end
end

-- Extremidades de los monos con cola, a cuatro patas. El brazo baja recto hasta la mano con el codo
-- un poco atrás; la pierna se dobla con la rodilla hacia delante ("bend") y el talón levantado detrás,
-- como en las fotos. La pieza articulada es el brazo o el muslo; antebrazo, espinilla, mano y pie van
-- pegados. "x", "y" y "z" son el hombro o la cadera; "upper" y "lower", los colores de cada tramo.
type Limb = {
	x: number,
	y: number,
	z: number,
	width: number,
	upper: Color3?,
	lower: Color3?,
	bend: number?,
}

local function fourLimbs(rig: Rig, torso: BasePart, fur: Color3, paws: Color3, arm: Limb, leg: Limb)
	for side = -1, 1, 2 do
		local name = sideName(side)

		local shoulder = Vector3.new(side * arm.x, arm.y, arm.z)
		local wrist = Vector3.new(side * arm.x, GROUND + 0.18, arm.z - 0.1)
		local elbow = shoulder:Lerp(wrist, 0.5) + Vector3.new(0, 0, 0.12)
		local upperArm, armAt = capsule(rig, `{name} Arm`, shoulder, elbow, arm.width, arm.upper or fur)
		joint(rig, torso, upperArm, `{name} Shoulder`, armAt, shoulder)
		glueCapsule(rig, upperArm, "Forearm", elbow, wrist, arm.width * 0.9, arm.lower or arm.upper or fur)
		feature(
			rig,
			upperArm,
			"Hand",
			Vector3.new(arm.width * 1.1, 0.2, arm.width * 1.5),
			paws,
			CFrame.new(wrist.X, GROUND + 0.1, wrist.Z - arm.width * 0.3)
		)

		local hip = Vector3.new(side * leg.x, leg.y, leg.z)
		local ankle = Vector3.new(side * leg.x, GROUND + 0.18, leg.z + 0.2)
		local knee = Vector3.new(side * leg.x, (hip.Y + ankle.Y) / 2, leg.z - (leg.bend or 0.35))
		local thigh, legAt = capsule(rig, `{name} Leg`, hip, knee, leg.width, leg.upper or fur)
		joint(rig, torso, thigh, `{name} Hip`, legAt, hip)
		glueCapsule(rig, thigh, "Shin", knee, ankle, leg.width * 0.75, leg.lower or leg.upper or fur)
		feature(
			rig,
			thigh,
			"Foot",
			Vector3.new(leg.width * 0.8, 0.2, leg.width * 1.9),
			paws,
			CFrame.new(ankle.X, GROUND + 0.1, ankle.Z - leg.width * 0.7)
		)
	end
end

-- Cola por tramos que pasan por "points"; el primero es la base, donde se articula. El primer tramo
-- es la pieza "Tail" y los demás van pegados a él, cada uno algo más fino. Desde el tramo "tipFrom"
-- (por defecto, el último) toma el color "tipColor".
type TailSpec = { points: { Vector3 }, width: number, color: Color3?, tipColor: Color3?, tipFrom: number? }

local function tail(rig: Rig, torso: BasePart, spec: TailSpec, fur: Color3)
	local points = spec.points
	local tipFrom = spec.tipFrom or #points - 1
	local first: BasePart? = nil
	for index = 1, #points - 1 do
		local color = if spec.tipColor and index >= tipFrom then spec.tipColor else spec.color or fur
		local width = spec.width * (1 - 0.1 * (index - 1))
		local part, at =
			capsule(rig, if first then "TailTip" else "Tail", points[index], points[index + 1], width, color)
		if first then
			glue(rig, first, part, at)
		else
			joint(rig, torso, part, "TailJoint", at, points[1])
			first = part
		end
	end
end

-- Monos con cola a cuatro patas: cuerpo (tilt positivo: el pecho más alto que la grupa), cabeza,
-- extremidades y cola. Devuelve el torso, la cabeza y su esfera para añadir los rasgos de cada especie.
type BodySpec = {
	fur: Color3,
	paws: Color3,
	torso: { size: Vector3, y: number, z: number, tilt: number },
	head: { diameter: number, y: number, z: number, color: Color3? },
	neck: Vector3,
	arm: Limb,
	leg: Limb,
	tail: TailSpec,
}

local function tailedMonkey(rig: Rig, spec: BodySpec): (BasePart, BasePart, Sphere)
	local body = spec.torso
	local torso = piece(rig, "Torso", "Oval", body.size, spec.fur)
	joint(
		rig,
		rig.root,
		torso,
		"RootJoint",
		CFrame.new(0, body.y, body.z) * CFrame.Angles(math.rad(body.tilt), 0, 0),
		Vector3.new(0, body.y, body.z)
	)
	local headSpec = spec.head
	local head = piece(rig, "Head", "Ball", Vector3.one * headSpec.diameter, headSpec.color or spec.fur)
	local center = Vector3.new(0, headSpec.y, headSpec.z)
	joint(rig, torso, head, "Neck", CFrame.new(center), spec.neck)
	fourLimbs(rig, torso, spec.fur, spec.paws, spec.arm, spec.leg)
	tail(rig, torso, spec.tail, spec.fur)
	return torso, head, { center = center, radius = headSpec.diameter / 2 }
end

-- Aullador rojo: lomo naranja rojizo y la cabeza, la barba y las patas granates; cara negra y desnuda
-- con una gran barba sobre la garganta (su caja de resonancia). Va encorvado, con la cabeza más baja
-- que los hombros, y la cola prensil sale recta hacia atrás y cae al final.
local function howler(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local skin = definition.faceColor
	local maroon = fur:Lerp(Color3.fromRGB(90, 20, 15), 0.5)
	local torso, head, sphere = tailedMonkey(rig, {
		fur = fur,
		paws = skin,
		torso = { size = Vector3.new(1.3, 1.15, 2.2), y = -0.2, z = 0.25, tilt = -4 },
		head = { diameter = 0.95, y = -0.05, z = -1.35, color = maroon },
		neck = Vector3.new(0, -0.2, -0.85),
		arm = { x = 0.52, y = -0.4, z = -0.6, width = 0.38, lower = maroon },
		leg = { x = 0.48, y = -0.35, z = 0.95, width = 0.48, lower = maroon },
		tail = {
			points = {
				Vector3.new(0, 0, 1.25),
				Vector3.new(0, 0, 2.4),
				Vector3.new(0, -0.4, 3.2),
				Vector3.new(0, -1.1, 3.5),
			},
			width = 0.28,
			tipColor = maroon,
		},
	})
	feature(rig, torso, "Shoulders", Vector3.new(1.4, 1.05, 1.3), fur, CFrame.new(0, -0.05, -0.4))
	feature(rig, head, "Beard", Vector3.new(0.85, 0.75, 0.75), darker(maroon, 0.15), CFrame.new(0, -0.4, -1.45))
	headPatch(rig, head, sphere, "Brow", Vector3.new(0.7, 0.2, 0.05), darker(maroon, 0.25), Vector3.new(0, 0.45, -1))
	headPatch(rig, head, sphere, "Face", Vector3.new(0.62, 0.62, 0.07), skin, Vector3.new(0, -0.05, -1))
	headPatch(rig, head, sphere, "Muzzle", Vector3.new(0.48, 0.36, 0.16), skin, Vector3.new(0, -0.4, -1))
	sphereEyes(rig, head, sphere, 0.3, 0.2, 0.1, 0.07)
end

-- Marimonda (mono araña del Chocó): toda negra, cabeza pequeña con la cara oscura y la barbilla
-- más clara, barriga redonda, brazos y piernas larguísimos y finos y una cola muy larga levantada
-- en forma de S, con la punta doblada hacia delante.
local function spiderMonkey(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local skin = definition.faceColor
	local torso, head, sphere = tailedMonkey(rig, {
		fur = fur,
		paws = skin,
		torso = { size = Vector3.new(1, 1, 1.6), y = 0, z = 0.15, tilt = 18 },
		head = { diameter = 0.8, y = 0.55, z = -0.95 },
		neck = Vector3.new(0, 0.25, -0.6),
		arm = { x = 0.3, y = -0.05, z = -0.35, width = 0.25 },
		leg = { x = 0.3, y = -0.35, z = 0.6, width = 0.3 },
		tail = {
			points = {
				Vector3.new(0, 0, 0.85),
				Vector3.new(0, 0.7, 1.45),
				Vector3.new(0, 1.6, 1.65),
				Vector3.new(0, 2.05, 1.3),
				Vector3.new(0, 1.85, 0.95),
			},
			width = 0.26,
		},
	})
	feature(
		rig,
		torso,
		"Belly",
		Vector3.new(0.8, 0.75, 0.95),
		fur:Lerp(Color3.new(1, 1, 1), 0.06),
		CFrame.new(0, -0.3, 0.25)
	)
	headPatch(rig, head, sphere, "Face", Vector3.new(0.48, 0.5, 0.07), skin, Vector3.new(0, -0.05, -1))
	headPatch(
		rig,
		head,
		sphere,
		"Muzzle",
		Vector3.new(0.3, 0.22, 0.16),
		skin:Lerp(Color3.new(1, 1, 1), 0.15),
		Vector3.new(0, -0.45, -1)
	)
	sphereEyes(rig, head, sphere, 0.3, 0.1, 0.09, 0.07)
end

-- Marteja (mono nocturno): cabeza redonda con unos ojos enormes que brillan en la oscuridad, manchas
-- blancas encima y tres rayas oscuras (una en medio y una a cada lado); pelo gris pardo, pecho
-- anaranjado y una cola gruesa con la punta negra.
local function nightMonkey(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local pale = definition.faceColor
	local stripe = Color3.fromRGB(45, 38, 32)
	local torso, head, sphere = tailedMonkey(rig, {
		fur = fur,
		paws = darker(fur, 0.35),
		torso = { size = Vector3.new(1, 0.95, 1.7), y = -0.3, z = 0.2, tilt = 4 },
		head = { diameter = 1.05, y = 0.2, z = -1.1 },
		neck = Vector3.new(0, -0.15, -0.7),
		arm = { x = 0.38, y = -0.5, z = -0.5, width = 0.28 },
		leg = { x = 0.38, y = -0.45, z = 0.8, width = 0.4, lower = fur:Lerp(Color3.fromRGB(150, 150, 150), 0.3) },
		tail = {
			points = {
				Vector3.new(0, -0.15, 1.05),
				Vector3.new(0, -0.5, 2),
				Vector3.new(0, -1.1, 2.7),
				Vector3.new(0, -1.35, 3.2),
			},
			width = 0.28,
			tipColor = stripe,
		},
	})
	feature(
		rig,
		torso,
		"Chest",
		Vector3.new(0.85, 0.6, 0.85),
		Color3.fromRGB(215, 160, 100),
		CFrame.new(0, -0.55, -0.35)
	)
	headPatch(
		rig,
		head,
		sphere,
		"Muzzle",
		Vector3.new(0.36, 0.26, 0.16),
		Color3.fromRGB(70, 60, 55),
		Vector3.new(0, -0.3, -1)
	)
	headPatch(rig, head, sphere, "Stripe", Vector3.new(0.09, 0.5, 0.04), stripe, Vector3.new(0, 0.6, -1))
	for side = -1, 1, 2 do
		headPatch(
			rig,
			head,
			sphere,
			"Patch",
			Vector3.new(0.3, 0.16, 0.05),
			pale,
			Vector3.new(side * 0.38, 0.45, -1),
			side * -0.3
		)
		headPatch(
			rig,
			head,
			sphere,
			"Stripe",
			Vector3.new(0.08, 0.45, 0.04),
			stripe,
			Vector3.new(side * 0.75, 0.35, -1),
			side * 0.2
		)
		-- Ojos que brillan, con la pupila delante.
		local direction = Vector3.new(side * 0.35, 0.05, -1).Unit
		local eye = sphere.center + direction * (sphere.radius - 0.08)
		glue(
			rig,
			head,
			piece(rig, "Eye", "Ball", Vector3.one * 0.3, Color3.fromRGB(255, 170, 60), Enum.Material.Neon),
			CFrame.new(eye)
		)
		glue(rig, head, piece(rig, "Pupil", "Ball", Vector3.one * 0.15, EYE_COLOR), CFrame.new(eye + direction * 0.09))
	end
end

-- Mandril: grande y oscuro, con la cabeza en punta, cejas pesadas, el hocico largo con las crestas
-- azules a los lados y la nariz roja, barba y collar amarillentos, trasero de colores y una cola
-- cortísima.
local function mandrill(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local red = definition.faceColor
	local blue = Color3.fromRGB(150, 185, 225)
	local cream = Color3.fromRGB(215, 190, 120)
	local torso, head, sphere = tailedMonkey(rig, {
		fur = fur,
		paws = Color3.fromRGB(50, 45, 40),
		torso = { size = Vector3.new(1.5, 1.35, 2.3), y = -0.1, z = 0.25, tilt = 14 },
		head = { diameter = 1.1, y = 0.45, z = -1.4 },
		neck = Vector3.new(0, 0.2, -0.9),
		arm = { x = 0.68, y = -0.25, z = -0.75, width = 0.5 },
		leg = { x = 0.55, y = -0.25, z = 1.05, width = 0.58 },
		tail = { points = { Vector3.new(0, 0, 1.4), Vector3.new(0, 0.25, 1.8) }, width = 0.2 },
	})
	feature(rig, torso, "Shoulders", Vector3.new(1.7, 1.2, 1.2), fur, CFrame.new(0, 0.15, -0.6))
	feature(rig, torso, "Collar", Vector3.new(1.4, 0.7, 0.9), cream, CFrame.new(0, 0.3, -0.95))
	feature(rig, torso, "Rump", Vector3.new(0.85, 0.75, 0.3), Color3.fromRGB(120, 90, 200), CFrame.new(0, -0.35, 1.45))
	feature(rig, head, "Crest", Vector3.new(0.6, 0.45, 0.7), fur, CFrame.new(0, 0.85, -1.35))
	headPatch(rig, head, sphere, "Brow", Vector3.new(0.85, 0.24, 0.1), darker(fur, 0.35), Vector3.new(0, 0.45, -1))
	feature(rig, head, "NoseRidge", Vector3.new(0.2, 0.2, 0.95), red, CFrame.new(0, 0.63, -2.03))
	feature(rig, head, "Nose", Vector3.new(0.34, 0.26, 0.2), red, CFrame.new(0, 0.5, -2.5))
	feature(
		rig,
		head,
		"Beard",
		Vector3.new(0.75, 0.42, 0.6),
		cream:Lerp(Color3.new(1, 1, 1), 0.2),
		CFrame.new(0, 0.05, -1.9)
	)
	for side = -1, 1, 2 do
		feature(
			rig,
			head,
			"Ridge",
			Vector3.new(0.28, 0.5, 0.95),
			blue,
			CFrame.new(side * 0.17, 0.42, -2) * CFrame.Angles(0, side * 0.08, 0)
		)
	end
	sphereEyes(rig, head, sphere, 0.33, 0.25, 0.12, 0, Color3.fromRGB(170, 110, 40))
end

-- Macaco (rhesus): pelo pardo grisáceo con los cuartos traseros y las piernas anaranjados, cara y
-- orejas rosadas enmarcadas por pelo más claro, cejas marcadas y cola mediana.
local function macaque(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local skin = definition.faceColor
	local orange = Color3.fromRGB(180, 110, 60)
	local torso, head, sphere = tailedMonkey(rig, {
		fur = fur,
		paws = darker(skin, 0.15),
		torso = { size = Vector3.new(1.2, 1.1, 2), y = -0.25, z = 0.2, tilt = 8 },
		head = { diameter = 0.95, y = 0.25, z = -1.25 },
		neck = Vector3.new(0, -0.05, -0.85),
		arm = { x = 0.5, y = -0.4, z = -0.6, width = 0.34 },
		leg = { x = 0.48, y = -0.35, z = 0.95, width = 0.46, upper = orange },
		tail = {
			points = { Vector3.new(0, -0.05, 1.2), Vector3.new(0, -0.25, 1.9), Vector3.new(0, -0.75, 2.3) },
			width = 0.22,
			color = orange,
		},
	})
	feature(
		rig,
		torso,
		"Haunches",
		Vector3.new(1.15, 0.95, 1),
		orange,
		CFrame.new(0, -0.25, 0.85) * CFrame.Angles(math.rad(8), 0, 0)
	)
	feature(
		rig,
		head,
		"Ruff",
		Vector3.new(0.95, 0.7, 0.5),
		fur:Lerp(Color3.new(1, 1, 1), 0.15),
		CFrame.new(0, 0.1, -1.45)
	)
	headPatch(rig, head, sphere, "Face", Vector3.new(0.62, 0.62, 0.07), skin, Vector3.new(0, -0.05, -1))
	headPatch(rig, head, sphere, "Muzzle", Vector3.new(0.42, 0.3, 0.16), skin, Vector3.new(0, -0.4, -1))
	headPatch(rig, head, sphere, "Brow", Vector3.new(0.6, 0.15, 0.1), darker(fur, 0.15), Vector3.new(0, 0.4, -1))
	sphereEyes(rig, head, sphere, 0.3, 0.15, 0.1, 0.07)
	for side = -1, 1, 2 do
		feature(rig, head, "Ear", Vector3.new(0.1, 0.28, 0.22), skin, CFrame.new(side * 0.47, 0.32, -1.2))
	end
end

-- Babuino (oliva): patas largas y la espalda que baja hacia la grupa; melena sobre el cuello y los
-- hombros, mejillas peludas, hocico largo como de perro con la cara gris oscura y los ojos hundidos
-- bajo la ceja, callos rosados en el trasero y la cola "rota": sube y luego cae.
local function baboon(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local skin = definition.faceColor
	local mane = fur:Lerp(Color3.new(1, 1, 1), 0.1)
	local torso, head, sphere = tailedMonkey(rig, {
		fur = fur,
		paws = darker(skin, 0.1),
		torso = { size = Vector3.new(1.25, 1.15, 2.2), y = 0, z = 0.25, tilt = 12 },
		head = { diameter = 0.95, y = 0.5, z = -1.35 },
		neck = Vector3.new(0, 0.2, -0.9),
		arm = { x = 0.58, y = -0.1, z = -0.75, width = 0.4 },
		leg = { x = 0.5, y = -0.2, z = 1, width = 0.5, bend = 0.3 },
		tail = {
			points = {
				Vector3.new(0, 0.15, 1.3),
				Vector3.new(0, 0.65, 1.75),
				Vector3.new(0, 0.5, 2.2),
				Vector3.new(0, -0.5, 2.4),
			},
			width = 0.24,
		},
	})
	feature(rig, torso, "Mane", Vector3.new(1.5, 1.25, 1.2), mane, CFrame.new(0, 0.2, -0.6))
	feature(rig, torso, "Callus", Vector3.new(0.6, 0.5, 0.25), Color3.fromRGB(200, 110, 110), CFrame.new(0, -0.45, 1.4))
	feature(rig, head, "Muzzle", Vector3.new(0.48, 0.45, 0.95), skin, CFrame.new(0, 0.32, -1.9))
	feature(rig, head, "Nose", Vector3.new(0.32, 0.25, 0.12), darker(skin, 0.3), CFrame.new(0, 0.38, -2.37))
	headPatch(rig, head, sphere, "Brow", Vector3.new(0.7, 0.2, 0.1), darker(skin, 0.2), Vector3.new(0, 0.45, -1))
	for side = -1, 1, 2 do
		feature(rig, head, "Cheek", Vector3.new(0.3, 0.6, 0.5), mane, CFrame.new(side * 0.42, 0.45, -1.5))
	end
	sphereEyes(rig, head, sphere, 0.33, 0.2, 0.11, 0, Color3.fromRGB(150, 100, 40))
end

-- Mono de cola larga (macaco cangrejero): pardo grisáceo con el vientre claro, patillas grises que se
-- abren en abanico alrededor de la cara, cara rosada grisácea, un copete en punta en la coronilla y
-- una cola larguísima que cuelga.
local function longTailedMacaque(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local pale = definition.faceColor
	local skin = Color3.fromRGB(190, 150, 135)
	local torso, head, sphere = tailedMonkey(rig, {
		fur = fur,
		paws = darker(skin, 0.2),
		torso = { size = Vector3.new(1.1, 1, 1.9), y = -0.3, z = 0.2, tilt = 6 },
		head = { diameter = 0.9, y = 0.22, z = -1.15 },
		neck = Vector3.new(0, -0.1, -0.75),
		arm = { x = 0.42, y = -0.45, z = -0.55, width = 0.3 },
		leg = { x = 0.4, y = -0.4, z = 0.9, width = 0.42 },
		tail = {
			points = {
				Vector3.new(0, -0.1, 1.1),
				Vector3.new(0, -0.35, 2.2),
				Vector3.new(0, -0.85, 3.1),
				Vector3.new(0, -1.55, 3.6),
			},
			width = 0.19,
			color = fur:Lerp(pale, 0.2),
		},
	})
	feature(rig, torso, "Belly", Vector3.new(0.85, 0.6, 1.3), fur:Lerp(pale, 0.5), CFrame.new(0, -0.55, 0.1))
	-- Patillas pegadas a los lados de la cabeza, peinadas hacia atrás y abajo, enmarcando la cara.
	for side = -1, 1, 2 do
		headPatch(
			rig,
			head,
			sphere,
			"Whiskers",
			Vector3.new(0.26, 0.42, 0.06),
			fur:Lerp(pale, 0.6),
			Vector3.new(side * 0.55, -0.35, -0.8),
			side * 0.3
		)
	end
	headPatch(rig, head, sphere, "Face", Vector3.new(0.52, 0.55, 0.07), skin, Vector3.new(0, 0, -1))
	headPatch(rig, head, sphere, "Muzzle", Vector3.new(0.34, 0.26, 0.16), skin, Vector3.new(0, -0.35, -1))
	headPatch(rig, head, sphere, "Crest", Vector3.new(0.24, 0.5, 0.08), fur, Vector3.new(0, 1, 0.15))
	sphereEyes(rig, head, sphere, 0.3, 0.15, 0.1, 0.07)
end

-- Gibón (de manos blancas): simio sin cola que en el suelo anda erguido, con los larguísimos brazos en
-- alto y algo doblados para equilibrarse y las piernas flexionadas. Pelo oscuro, cara negra rodeada
-- de un anillo claro, y manos y pies claros.
local function gibbon(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local pale = definition.faceColor
	local torso = piece(rig, "Torso", "Oval", Vector3.new(1, 1.45, 0.8), fur)
	joint(rig, rig.root, torso, "RootJoint", CFrame.new(0, -0.05, 0), Vector3.new(0, -0.05, 0))
	local head = piece(rig, "Head", "Ball", Vector3.one * 0.85, fur)
	joint(rig, torso, head, "Neck", CFrame.new(0, 1, -0.05), Vector3.new(0, 0.7, 0))
	feature(rig, head, "FaceRing", Vector3.new(0.66, 0.7, 0.2), pale, CFrame.new(0, 0.98, -0.38))
	feature(rig, head, "Face", Vector3.new(0.48, 0.52, 0.25), Color3.fromRGB(25, 22, 20), CFrame.new(0, 0.98, -0.42))
	eyes(rig, head, 0.11, 1.06, -0.53, 0.1)
	for side = -1, 1, 2 do
		local name = sideName(side)
		-- Brazos en alto, abiertos desde el hombro y con el codo doblado hacia fuera.
		local shoulder = Vector3.new(side * 0.5, 0.5, 0)
		local elbow = shoulder + Vector3.new(side * 0.8, 0.8, 0.05)
		local wrist = elbow + Vector3.new(side * 0.3, 0.95, -0.05)
		local arm, armAt = capsule(rig, `{name} Arm`, shoulder, elbow, 0.26, fur)
		joint(rig, torso, arm, `{name} Shoulder`, armAt, shoulder)
		glueCapsule(rig, arm, "Forearm", elbow, wrist, 0.22, fur)
		glueCapsule(rig, arm, "Hand", wrist, wrist + Vector3.new(side * 0.05, 0.25, 0), 0.24, pale)

		local hip = Vector3.new(side * 0.3, -0.6, 0.05)
		local knee = Vector3.new(side * 0.36, -1.15, -0.25)
		local ankle = Vector3.new(side * 0.32, GROUND + 0.15, 0.1)
		local leg, legAt = capsule(rig, `{name} Leg`, hip, knee, 0.36, fur)
		joint(rig, torso, leg, `{name} Hip`, legAt, hip)
		glueCapsule(rig, leg, "Shin", knee, ankle, 0.28, fur)
		feature(rig, leg, "Foot", Vector3.new(0.3, 0.2, 0.6), pale, CFrame.new(ankle.X, GROUND + 0.1, -0.12))
	end
end

---------------------------------------------------------------------------------------------------
-- Estilo voxel (en pruebas): cajas alineadas a una rejilla, leídas de un spec de VoxelSpecs/<Especie>.
-- Cada parte del spec es una pieza animable con el nombre de siempre (Torso, Head, Right Arm…): todas
-- sus cajas se unen en una sola pieza (ver mergeBoxes), salvo las de VOXEL_LOOSE, que van soldadas
-- aparte porque otros sistemas las buscan por nombre. Una caja es
-- { x, y, z, ancho, alto, fondo, tono, nombre?, simétrica? } en celdas de spec.unit studs, con y
-- medida desde el suelo; el tono es una clave de voxelTones o un Color3 fijo (el moteado de ceniza).
-- "simétrica" añade su reflejo en -X; una parte con "mirror" se describe del
-- lado derecho y sale también la izquierda ("Right Arm" / "Left Arm").

type VoxelPart = {
	name: string,
	joint: string,
	parent: string?,
	pivot: { number }?,
	mirror: boolean?,
	boxes: { { any } },
}
-- Adorno de un jefe: bloques de un mismo material pegados a "anchor" y unidos en una pieza "name".
-- Las cajas son como las de las partes; sin tono, usan "color" (o el tono "tone") del grupo. Con
-- "phase", el grupo solo se ve en esa fase del combate (expresiones de la cara, venas que se encienden).
type VoxelExtra = {
	anchor: string,
	name: string,
	color: Color3?,
	tone: string?,
	material: string?,
	transparency: number?,
	mirror: boolean?,
	phase: number?,
	boxes: { { any } },
}
-- Lo que un jefe cambia del cuerpo de su especie: "remove" quita las cajas con esos nombres (la cara
-- que va por fases), "add" añade cajas a una parte (músculos: se unen con ella, sin piezas de más) y
-- "groups" son sus adornos. "tones" cambia tonos de voxelTones solo para este jefe (el lomo de ceniza).
type VoxelBoss = {
	tones: { [string]: Color3 }?,
	remove: { string }?,
	add: { [string]: { { any } } }?,
	groups: { VoxelExtra }?,
}
export type VoxelSpec = { unit: number, parts: { VoxelPart }, bosses: { [string]: VoxelBoss }? }

-- Los tonos del spec, sacados de los colores de Data (bodyColor = pelo, faceColor = piel).
local function voxelTones(definition: Monkeys.MonkeyDefinition): { [string]: Color3 }
	local fur = definition.bodyColor
	local skin = definition.faceColor
	return {
		fur = fur,
		shag = fur:Lerp(Color3.new(1, 1, 1), 0.08),
		chest = fur:Lerp(skin, 0.4),
		silver = fur:Lerp(Color3.fromRGB(215, 215, 220), 0.5),
		skin = skin,
		paws = darker(skin, 0.08),
		dark = darker(skin, 0.45),
		mouth = darker(skin, 0.7),
		eye = skin:Lerp(Color3.new(1, 1, 1), 0.55),
		teeth = EYE_WHITE,
	}
end

-- Cajas que no se unen: glowEyes enciende los "Eye" y el Gorila de Ceniza recolorea "Chest" y "Pec".
local VOXEL_LOOSE: { [string]: boolean } = { Eye = true, Chest = true, Pec = true }

-- Une "boxes" a "main" en una sola pieza con el nombre de "main". Lo que cuesta en cada fotograma
-- son las piezas que se mueven, no los bloques: con 160 gorilas de 120 bloques sueltos un PC bajaba
-- a ~8 FPS y unidos por extremidad (8 piezas por mono) iba a 60. Unir tarda ~100 ms por mono, pero
-- los monos normales se copian de una plantilla. Si la unión falla, las cajas quedan soldadas.
local function mergeBoxes(main: BasePart, boxes: { BasePart }): BasePart
	if #boxes == 0 then
		return main
	end
	local ok, result = pcall(function()
		return GeometryService:UnionAsync(main, boxes, {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
			SplitApart = false,
		})
	end)
	local union = if ok then result[1] else nil
	if not union then
		warn(`[MonkeyModels] No se pudieron unir las cajas de {main.Name}: {result}`)
		for _, box in boxes do
			weld(main, box)
		end
		return main
	end
	union.Name = main.Name
	union.UsePartColor = false -- conserva el color de cada caja
	union.Material = main.Material
	union.Transparency = main.Transparency
	union.CastShadow = main.CastShadow
	union.CanCollide = false
	union.Massless = true
	union.Parent = main.Parent
	main:Destroy()
	for _, box in boxes do
		box:Destroy()
	end
	return union
end

-- Muestra las piezas de la fase "phase" del combate (atributo "Phase", ver VoxelExtra) y esconde las
-- de las demás. Si el jefe no tiene nada para esa fase, se queda con lo de la anterior que sí tenga.
local function showPhase(model: Model, phase: number)
	local shown = 0
	for _, part in model:GetDescendants() do
		local partPhase = part:GetAttribute("Phase")
		if typeof(partPhase) == "number" and partPhase <= phase and partPhase > shown then
			shown = partPhase
		end
	end
	for _, part in model:GetDescendants() do
		local partPhase = part:GetAttribute("Phase")
		if part:IsA("BasePart") and partPhase then
			part.Transparency = if partPhase == shown then part:GetAttribute("BaseTransparency") :: number else 1
		end
	end
end

local function voxelMonkey(rig: Rig, definition: Monkeys.MonkeyDefinition, spec: VoxelSpec, bossId: string?)
	local tones = voxelTones(definition)
	local function toneOf(value: any): Color3?
		return if typeof(value) == "Color3" then value elseif value then tones[value] else nil
	end
	local unit = spec.unit
	local function at(x: number, y: number, z: number): Vector3
		return Vector3.new(x * unit, y * unit + GROUND, z * unit)
	end
	local boss: VoxelBoss = if bossId and spec.bosses then spec.bosses[bossId] or {} else {}
	for name, color in boss.tones or {} do
		tones[name] = color
	end
	local removed: { [string]: boolean } = {}
	for _, name in boss.remove or {} do
		removed[name] = true
	end
	for _, part in spec.parts do
		local boxes = table.clone(part.boxes)
		local added = if boss.add then boss.add[part.name] else nil
		if added then
			table.move(added, 1, #added, #boxes + 1, boxes)
		end
		for _, side in if part.mirror then { 1, -1 } else { 0 } do
			local prefix = if side == 0 then "" else `{sideName(side)} `
			local flip = if side == -1 then -1 else 1
			local main: BasePart? = nil
			local merged: { BasePart } = {}
			local loose: { BasePart } = {}
			for index, box in boxes do
				if index > 1 and removed[box[8] :: string] then
					continue
				end
				local x, y, z = box[1] :: number, box[2] :: number, box[3] :: number
				local size = Vector3.new(box[4] :: number, box[5] :: number, box[6] :: number) * unit
				local color = toneOf(box[7]) :: Color3
				local name = if main == nil then prefix .. part.name else (box[8] :: string?) or "Voxel"
				for _, mirrorX in if box[9] then { 1, -1 } else { 1 } do
					local block = piece(rig, name, "Block", size, color)
					place(rig, block, CFrame.new(at(x * flip * mirrorX, y, z)))
					if main == nil then
						main = block
					else
						table.insert(if VOXEL_LOOSE[name] then loose else merged, block)
					end
				end
			end
			local animated = mergeBoxes(main :: BasePart, merged)
			local parentPart = if part.parent then partNamed(rig, part.parent) else rig.root
			local pivot = part.pivot
			local pivotAt = if pivot then at(pivot[1] * flip, pivot[2], pivot[3]) else Vector3.zero
			attach(rig, parentPart, animated, prefix .. part.joint, pivotAt)
			for _, block in loose do
				weld(animated, block)
			end
		end
	end

	-- Adornos del jefe: cada grupo, unido en una pieza de su material y soldado a su parte.
	for _, extra in boss.groups or {} do
		local material = (Enum.Material :: any)[extra.material or "SmoothPlastic"] :: Enum.Material
		local groupColor = extra.color or tones[extra.tone or "fur"]
		for _, side in if extra.mirror then { 1, -1 } else { 0 } do
			local flip = if side == -1 then -1 else 1
			local blocks: { BasePart } = {}
			for _, box in extra.boxes do
				local size = Vector3.new(box[4] :: number, box[5] :: number, box[6] :: number) * unit
				local color = toneOf(box[7]) or groupColor
				for _, mirrorX in if box[9] then { 1, -1 } else { 1 } do
					local block = piece(rig, extra.name, "Block", size, color, material)
					block.Transparency = extra.transparency or 0
					block.CastShadow = false
					place(
						rig,
						block,
						CFrame.new(at((box[1] :: number) * flip * mirrorX, box[2] :: number, box[3] :: number))
					)
					table.insert(blocks, block)
				end
			end
			local anchor = partNamed(rig, if side == 0 then extra.anchor else `{sideName(side)} {extra.anchor}`)
			local first = table.remove(blocks, 1) :: BasePart
			local group = mergeBoxes(first, blocks)
			weld(anchor, group)
			if extra.phase then
				group:SetAttribute("Phase", extra.phase)
				group:SetAttribute("BaseTransparency", group.Transparency)
			end
		end
	end
	showPhase(rig.model, 1)
end
MonkeyModels.showPhase = showPhase

-- Especies con modelo voxel en el juego.
local VOXEL_SPECS: { [string]: VoxelSpec } = {
	Gorila = require(script.Parent.VoxelSpecs.Gorila) :: any,
	Titi = require(script.Parent.VoxelSpecs.Titi) :: any,
	MonoArdilla = require(script.Parent.VoxelSpecs.MonoArdilla) :: any,
	CapuchinoLadron = require(script.Parent.VoxelSpecs.CapuchinoLadron) :: any,
}
-- Jefes que ya usan el cuerpo voxel de su especie, con sus adornos en bloques. Los demás siguen con
-- el modelo de antes hasta que tengan sus detalles. La vista previa los activa en su copia del módulo
-- (MM.voxelBosses.GorilaAlbino = true) para probarlos. Si su especie ya no tiene constructor redondo
-- (como el gorila), el jefe tiene que estar aquí o saldría con el cuerpo del mono genérico.
local VOXEL_BOSSES: { [string]: boolean } = {
	GorilaAlbino = true,
	GorilaDeCeniza = true,
}
MonkeyModels.voxelSpecs = VOXEL_SPECS
MonkeyModels.voxelBosses = VOXEL_BOSSES

local BUILDERS: { [string]: (rig: Rig, definition: Monkeys.MonkeyDefinition) -> () } = {
	AulladorRojo = howler,
	Marimonda = spiderMonkey,
	Marteja = nightMonkey,
	Mandril = mandrill,
	Macaco = macaque,
	Gibon = gibbon,
	Babuino = baboon,
	ColaLarga = longTailedMacaque,
	Chimpance = chimpanzee,
	Orangutan = orangutan,
}

---------------------------------------------------------------------------------------------------
-- Detalles de los jefes, sobre el modelo de su especie base y en sus mismas coordenadas.

local function glowEyes(rig: Rig, color: Color3)
	for _, child in rig.model:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Eye" then
			child.Color = color
			child.Material = Enum.Material.Neon
		end
	end
end

local function glow(rig: Rig, part: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.min(range * rig.scale, 60)
	light.Brightness = brightness
	light.Parent = part
end

local BOSS_EXTRAS: { [string]: (rig: Rig) -> () } = {
	-- Orangután del Manglar: musgo en el lomo y en la cabeza, musgo colgando de los brazos (como el
	-- de las ramas del manglar) y una liana con hojas cruzada en el pecho.
	OrangutanDelManglar = function(rig)
		local moss = Color3.fromRGB(85, 120, 50)
		local torso = partNamed(rig, "Torso")
		local head = partNamed(rig, "Head")
		for _, patch in
			{
				{ anchor = torso, size = Vector3.new(1, 0.35, 1.1), at = CFrame.new(0.45, 1.08, -0.2) },
				{ anchor = torso, size = Vector3.new(0.85, 0.3, 0.95), at = CFrame.new(-0.45, 0.98, 0.6) },
				{ anchor = head, size = Vector3.new(0.55, 0.2, 0.55), at = CFrame.new(-0.28, 1.28, -0.98) },
			}
		do
			glue(rig, patch.anchor, piece(rig, "Moss", "Oval", patch.size, moss, Enum.Material.Grass), patch.at)
		end
		for side = -1, 1, 2 do
			glue(
				rig,
				partNamed(rig, `{sideName(side)} Arm`),
				piece(rig, "Moss", "Oval", Vector3.new(0.22, 1, 0.3), moss, Enum.Material.Grass),
				CFrame.new(side * 1.3, -0.55, -0.95) * CFrame.Angles(0, 0, side * 0.1)
			)
		end
		-- La liana va del hombro derecho a la cadera izquierda, por delante de la barriga.
		local sash = CFrame.new(0, 0.3, -0.85) * CFrame.Angles(0, 0, math.rad(-40))
		feature(rig, torso, "Vine", Vector3.new(0.22, 2.5, 0.22), Color3.fromRGB(70, 110, 40), sash)
		for index, offset in { -0.75, 0.15, 0.85 } do
			feature(
				rig,
				torso,
				"Leaf",
				Vector3.new(0.3, 0.07, 0.45),
				Color3.fromRGB(60, 140, 60),
				sash * CFrame.new(0.12, offset, -0.12) * CFrame.Angles(math.rad(-70), math.rad(index * 60 - 120), 0)
			)
		end
	end,

	-- Chimpancé Caudillo: tocado en abanico de plumas azules, doradas, rojas y naranjas sobre una
	-- banda de cuentas en la frente, y un collar de cuentas de madera con una nuez colgando en el pecho.
	ChimpanceCaudillo = function(rig)
		local head = partNamed(rig, "Head")
		local torso = partNamed(rig, "Torso")
		local wood = Color3.fromRGB(150, 92, 50)
		local band = CFrame.new(0, 0.9, -1.3)
		glue(
			rig,
			head,
			piece(rig, "Headband", "Cylinder", Vector3.new(0.2, 1.04, 1.04), wood, Enum.Material.Wood),
			band * CFrame.Angles(0, 0, math.rad(90))
		)
		-- Cuentas claras y de colores en el frente de la banda.
		local beads = { Color3.fromRGB(235, 225, 200), Color3.fromRGB(60, 120, 200), Color3.fromRGB(200, 50, 40) }
		for index = -2, 2 do
			local angle = index * 0.38
			glue(
				rig,
				head,
				piece(rig, "Bead", "Ball", Vector3.one * 0.15, beads[math.abs(index) % 3 + 1]),
				band * CFrame.new(math.sin(angle) * 0.54, 0, -math.cos(angle) * 0.54)
			)
		end
		-- Las plumas salen de la banda y se abren hacia arriba y a los lados, como un abanico.
		local feathers = {
			Color3.fromRGB(45, 105, 200),
			Color3.fromRGB(240, 190, 60),
			Color3.fromRGB(215, 50, 40),
			Color3.fromRGB(240, 130, 45),
			Color3.fromRGB(90, 170, 225),
		}
		local count = 9
		for index = 1, count do
			local angle = math.rad(-80 + (index - 1) * 160 / (count - 1))
			local length = 1.25 - math.abs(angle) * 0.25
			local direction = Vector3.new(math.sin(angle), math.cos(angle), 0.25).Unit
			glue(
				rig,
				head,
				piece(rig, "Feather", "Oval", Vector3.new(0.1, length, 0.3), feathers[(index - 1) % #feathers + 1]),
				CFrame.new(Vector3.new(0, 0.95, -1.15) + direction * (0.3 + length / 2))
					* CFrame.Angles(math.rad(-14), 0, -angle)
			)
		end

		-- Collar: cuentas de madera en U por delante del pecho y la nuez colgando del centro.
		local necklace = 7
		for index = 1, necklace do
			local t = (index - 1) / (necklace - 1) * 2 - 1
			glue(
				rig,
				torso,
				piece(rig, "Bead", "Ball", Vector3.one * 0.2, if index % 2 == 0 then darker(wood, 0.25) else wood),
				CFrame.new(t * 0.6, 0.15 - (1 - t * t) * 0.45, -1.02 - (1 - t * t) * 0.12)
			)
		end
		feature(
			rig,
			torso,
			"Nut",
			Vector3.new(0.3, 0.42, 0.28),
			Color3.fromRGB(125, 80, 45),
			CFrame.new(0, -0.55, -1.18),
			Enum.Material.Wood
		)
	end,

	-- Gorila Albino: cristales de rubí en racimos sobre los hombros, el lomo y los brazos, y el corazón
	-- encendido en el pecho (en bloques, en su spec); aquí solo se añaden la luz y las chispas rojas.
	GorilaAlbino = function(rig)
		local ruby = Color3.fromRGB(205, 25, 45)
		local torso = partNamed(rig, "Torso")
		glow(rig, partNamed(rig, "CrystalCore"), ruby, 6, 1)

		local s = rig.scale
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "Chispas"
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 80, 90), Color3.fromRGB(190, 20, 40))
		sparks.LightEmission = 0.6
		sparks.Size = NumberSequence.new(0.1 * s, 0)
		sparks.Lifetime = NumberRange.new(1, 1.8)
		sparks.Rate = 6
		sparks.Speed = NumberRange.new(0.5 * s, 1.2 * s)
		sparks.SpreadAngle = Vector2.new(60, 60)
		sparks.Acceleration = Vector3.new(0, -0.5 * s, 0)
		sparks.Parent = torso
	end,

	-- Gorila de Ceniza: ojos de fuego, ascuas y humo (las grietas de lava van en bloques en su spec).
	GorilaDeCeniza = function(rig)
		local lava = Color3.fromRGB(255, 110, 30)
		glowEyes(rig, Color3.fromRGB(255, 170, 60))
		local torso = partNamed(rig, "Torso")
		-- El pecho es roca apagada, no del naranja de la cara: así la lava de las grietas destaca.
		local charcoal = Color3.fromRGB(45, 40, 40)
		for _, child in rig.model:GetChildren() do
			if child:IsA("BasePart") and (child.Name == "Chest" or child.Name == "Pec") then
				child.Color = charcoal
			end
		end
		-- Alcance corto: con 12 (43 studs a su escala) teñía todo el cuerpo de naranja y tapaba el
		-- moteado de ceniza. Así ilumina el suelo de alrededor.
		glow(rig, torso, lava, 5, 2)

		local s = rig.scale
		local embers = Instance.new("ParticleEmitter")
		embers.Name = "Ascuas"
		embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		embers.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 70, 20))
		embers.LightEmission = 1
		embers.Size = NumberSequence.new(0.12 * s, 0)
		embers.Lifetime = NumberRange.new(1, 2)
		embers.Rate = 10
		embers.Speed = NumberRange.new(1 * s, 2 * s)
		embers.SpreadAngle = Vector2.new(40, 40)
		embers.Acceleration = Vector3.new(0, 1.5 * s, 0)
		embers.Parent = torso
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "Humo"
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.fromRGB(80, 75, 72))
		smoke.Size = NumberSequence.new(0.6 * s, 2 * s)
		smoke.Transparency = NumberSequence.new(0.5, 1)
		smoke.Lifetime = NumberRange.new(2, 3)
		smoke.Rate = 3
		smoke.Speed = NumberRange.new(0.6 * s, 1.2 * s)
		smoke.RotSpeed = NumberRange.new(-20, 20)
		smoke.Parent = torso
	end,
}

-- Altura de la raíz sobre el suelo para que las patas lo toquen (ver HipHeight).
function MonkeyModels.rootHeight(scale: number): number
	return 1.9 * scale
end

-- Construye un mono nuevo. "ground" es el punto del suelo donde aparece. Los jefes lo usan con su
-- propio aspecto y su id ("bossId", para sus detalles); los monos normales salen de MonkeyModels.spawn.
function MonkeyModels.build(
	speciesId: string,
	definition: Monkeys.MonkeyDefinition,
	ground: Vector3,
	bossId: string?
): Model
	local s = definition.scale
	local model = Instance.new("Model")
	model.Name = definition.name
	model:SetAttribute("MonkeyType", speciesId)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * s
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = CFrame.new(ground + Vector3.new(0, MonkeyModels.rootHeight(s), 0))
	root.Parent = model
	model.PrimaryPart = root

	local voxelSpec = if bossId and not VOXEL_BOSSES[bossId] then nil else VOXEL_SPECS[speciesId]
	local rig: Rig = { model = model, root = root, scale = s, boss = bossId ~= nil, voxel = voxelSpec ~= nil }
	if voxelSpec then
		voxelMonkey(rig, definition, voxelSpec, bossId)
	else
		local builder = BUILDERS[speciesId] or genericMonkey
		builder(rig, definition)
	end
	local extras = if bossId then BOSS_EXTRAS[bossId] else nil
	if extras then
		extras(rig)
	end

	local humanoid = Instance.new("Humanoid")
	-- R15 a propósito: la raíz queda a HipHeight + la mitad de su altura sobre el suelo (rootHeight).
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.AutomaticScalingEnabled = false
	humanoid.DisplayName = definition.name
	humanoid.MaxHealth = definition.maxHealth
	humanoid.Health = definition.maxHealth
	humanoid.WalkSpeed = definition.walkSpeed
	humanoid.HipHeight = 0.9 * s
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid
	return model
end

-- Un mono de la especie en "ground", copiado de su plantilla (más barato que construirlo pieza a pieza).
function MonkeyModels.spawn(speciesId: string, definition: Monkeys.MonkeyDefinition, ground: Vector3): Model
	local template = templates[speciesId]
	if not template then
		template = MonkeyModels.build(speciesId, definition, Vector3.zero)
		templates[speciesId] = template
	end
	local model = template:Clone()
	model:PivotTo(CFrame.new(ground + Vector3.new(0, MonkeyModels.rootHeight(definition.scale), 0)))
	return model
end

-- Un jefe en "ground", copiado de su plantilla: unir sus bloques tarda (~0,5 ms por bloque; 500
-- bloques, ~270 ms), así que se construye una vez por servidor. "look" es su aspecto (como en build);
-- la vida y la velocidad cambian en cada aparición, así que se ponen en la copia.
function MonkeyModels.spawnBoss(
	speciesId: string,
	look: Monkeys.MonkeyDefinition,
	ground: Vector3,
	bossId: string
): Model
	local template = bossTemplates[bossId]
	if not template then
		template = MonkeyModels.build(speciesId, look, Vector3.zero, bossId)
		bossTemplates[bossId] = template
	end
	local model = template:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = look.name
	humanoid.MaxHealth = look.maxHealth
	humanoid.Health = look.maxHealth
	humanoid.WalkSpeed = look.walkSpeed
	model:PivotTo(CFrame.new(ground + Vector3.new(0, MonkeyModels.rootHeight(look.scale), 0)))
	-- Cambia la cara (y lo demás que va por fases) cuando BossService cambia de fase.
	model:GetAttributeChangedSignal("BossPhase"):Connect(function()
		MonkeyModels.showPhase(model, model:GetAttribute("BossPhase") :: number? or 1)
	end)
	return model
end

return MonkeyModels
