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
-- Los simios (gorila, chimpancé, orangután, gibón) no tienen cola. Los jefes añaden sus detalles (BOSS_EXTRAS).
-- Cada especie se construye una vez como plantilla y los monos son copias (MonkeyModels.spawn).
-- El Humanoid lo mueve como a un personaje.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)

-- Las posiciones de los constructores son respecto a la raíz, a escala 1, con la cara hacia -Z.
-- La raíz está a rootHeight sobre el suelo: con escala 1, el suelo queda en Y = -1.9.
type Rig = { model: Model, root: BasePart, scale: number }

type Shape = "Block" | "Ball" | "Oval" | "Cylinder"

local MonkeyModels = {}

local EYE_COLOR = Color3.fromRGB(20, 15, 10)
local GROUND = -1.9 -- altura del suelo respecto a la raíz, a escala 1

local templates: { [string]: Model } = {}

local function piece(rig: Rig, name: string, shape: Shape, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif shape == "Oval" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
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

-- Articula "part1" (que queda en "rest") a "part0" (ya colocada). Gira sobre "pivot" (hombro,
-- cadera…) con los ejes del modelo: girar en X balancea adelante/atrás, en Y gira a los lados y en Z
-- inclina de costado.
local function joint(rig: Rig, part0: BasePart, part1: BasePart, name: string, rest: CFrame, pivot: Vector3)
	place(rig, part1, rest)
	local pivotFrame = rig.root.CFrame * CFrame.new(pivot * rig.scale)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:ToObjectSpace(pivotFrame)
	motor.C1 = part1.CFrame:ToObjectSpace(pivotFrame)
	motor.Parent = part0
end

-- Pieza decorativa que sigue a "anchor" sin moverse por su cuenta.
local function glue(rig: Rig, anchor: BasePart, part: BasePart, rest: CFrame)
	place(rig, part, rest)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
end

local function sideName(side: number): string
	return if side == 1 then "Right" else "Left"
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

-- Mono ardilla (Saimiri): pequeño y esbelto, a cuatro patas. Gorro oscuro, cara blanca con hocico
-- negro, espalda gris oliva, brazos y piernas dorados y una cola muy larga con la punta negra.
-- Colores de Data/Monkeys: bodyColor = extremidades, faceColor = cara.
local SAIMIRI_BACK = Color3.fromRGB(128, 122, 82)
local SAIMIRI_BELLY = Color3.fromRGB(238, 222, 170)
local SAIMIRI_DARK = Color3.fromRGB(38, 34, 30)

local function squirrelMonkey(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local limbs = definition.bodyColor
	local face = definition.faceColor

	-- Cuerpo horizontal y vientre claro.
	local torso = piece(rig, "Torso", "Oval", Vector3.new(1.05, 0.95, 2), SAIMIRI_BACK)
	joint(rig, rig.root, torso, "RootJoint", CFrame.new(0, -0.35, 0.15), Vector3.new(0, -0.35, 0.15))
	glue(rig, torso, piece(rig, "Belly", "Oval", Vector3.new(0.85, 0.6, 1.6), SAIMIRI_BELLY), CFrame.new(0, -0.6, 0.1))

	-- Cabeza redonda y blanca con el gorro oscuro encima, ojos grandes y hocico negro.
	local head = piece(rig, "Head", "Ball", Vector3.one * 1.15, face)
	joint(rig, torso, head, "Neck", CFrame.new(0, 0.3, -1.15), Vector3.new(0, -0.05, -0.75))
	glue(rig, head, piece(rig, "Cap", "Oval", Vector3.new(1.2, 0.75, 1.15), SAIMIRI_DARK), CFrame.new(0, 0.55, -1.03))
	glue(rig, head, piece(rig, "Muzzle", "Oval", Vector3.new(0.5, 0.38, 0.4), SAIMIRI_DARK), CFrame.new(0, 0.1, -1.65))

	for side = -1, 1, 2 do
		glue(rig, head, piece(rig, "Eye", "Ball", Vector3.one * 0.22, EYE_COLOR), CFrame.new(side * 0.2, 0.42, -1.66))
		glue(
			rig,
			head,
			piece(rig, "Ear", "Oval", Vector3.new(0.12, 0.38, 0.3), face),
			CFrame.new(side * 0.6, 0.35, -1.05)
		)

		-- Patas delanteras (los brazos) y traseras, más largas, con manos y pies.
		local arm = piece(rig, `{sideName(side)} Arm`, "Oval", Vector3.new(0.3, 1.4, 0.32), limbs)
		joint(
			rig,
			torso,
			arm,
			`{sideName(side)} Shoulder`,
			CFrame.new(side * 0.38, -1.2, -0.55),
			Vector3.new(side * 0.38, -0.55, -0.55)
		)
		glue(
			rig,
			arm,
			piece(rig, "Hand", "Oval", Vector3.new(0.34, 0.16, 0.42), limbs),
			CFrame.new(side * 0.38, -1.85, -0.62)
		)

		local leg = piece(rig, `{sideName(side)} Leg`, "Oval", Vector3.new(0.38, 1.35, 0.4), limbs)
		joint(
			rig,
			torso,
			leg,
			`{sideName(side)} Hip`,
			CFrame.new(side * 0.4, -1.2, 0.75),
			Vector3.new(side * 0.4, -0.6, 0.75)
		)
		glue(
			rig,
			leg,
			piece(rig, "Thigh", "Oval", Vector3.new(0.45, 0.75, 0.65), SAIMIRI_BACK),
			CFrame.new(side * 0.4, -0.75, 0.72)
		)
		glue(
			rig,
			leg,
			piece(rig, "Foot", "Oval", Vector3.new(0.38, 0.16, 0.55), limbs),
			CFrame.new(side * 0.4, -1.84, 0.65)
		)
	end

	-- Cola larga que cae hacia atrás y termina en una punta negra enroscada hacia arriba.
	local tail = piece(rig, "Tail", "Oval", Vector3.new(0.18, 0.18, 3), SAIMIRI_BACK)
	joint(
		rig,
		torso,
		tail,
		"TailJoint",
		CFrame.new(0, -0.49, 2.55) * CFrame.Angles(math.rad(15), 0, 0),
		Vector3.new(0, -0.1, 1.1)
	)
	glue(
		rig,
		tail,
		piece(rig, "TailTip", "Oval", Vector3.new(0.22, 0.22, 1), SAIMIRI_DARK),
		CFrame.new(0, -0.6, 4.28) * CFrame.Angles(math.rad(-45), 0, 0)
	)
end

-- Extremidades de los monos a cuatro patas (los simios se apoyan en los nudillos): brazos y piernas
-- que llegan al suelo, con manos y pies del color de la piel. "x" y "z" sitúan cada extremidad; size.Y es su largo.
type Limb = { size: Vector3, x: number, z: number }

local function groundLimbs(rig: Rig, torso: BasePart, fur: Color3, skin: Color3, arm: Limb, leg: Limb)
	for side = -1, 1, 2 do
		for _, limb in
			{
				{ spec = arm, part = "Arm", joint = "Shoulder", paw = "Hand", pawLength = 1.15 },
				{ spec = leg, part = "Leg", joint = "Hip", paw = "Foot", pawLength = 1.4 },
			}
		do
			local size = limb.spec.size
			local x = side * limb.spec.x
			local z = limb.spec.z
			local part = piece(rig, `{sideName(side)} {limb.part}`, "Oval", size, fur)
			joint(
				rig,
				torso,
				part,
				`{sideName(side)} {limb.joint}`,
				CFrame.new(x, GROUND + size.Y / 2, z),
				Vector3.new(x, GROUND + size.Y - size.X * 0.5, z)
			)
			glue(
				rig,
				part,
				piece(rig, limb.paw, "Oval", Vector3.new(size.X, 0.3, size.Z * limb.pawLength), skin),
				CFrame.new(x, GROUND + 0.13, z - 0.1)
			)
		end
	end
end

local function eyes(rig: Rig, head: BasePart, spread: number, y: number, z: number, diameter: number)
	for side = -1, 1, 2 do
		glue(rig, head, piece(rig, "Eye", "Ball", Vector3.one * diameter, EYE_COLOR), CFrame.new(side * spread, y, z))
	end
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- Gorila (lomo plateado): enorme, hombros anchos y altos, brazos larguísimos y piernas cortas.
-- Cabeza con cresta, cejas muy marcadas y cara negra. bodyColor = pelo, faceColor = piel.
local function gorilla(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local skin = definition.faceColor
	local tilt = CFrame.Angles(math.rad(18), 0, 0)
	local torso = piece(rig, "Torso", "Oval", Vector3.new(2, 1.7, 2.6), fur)
	joint(rig, rig.root, torso, "RootJoint", CFrame.new(0, -0.05, 0.3) * tilt, Vector3.new(0, -0.05, 0.3))
	glue(rig, torso, piece(rig, "Shoulders", "Oval", Vector3.new(2.4, 1.5, 1.5), fur), CFrame.new(0, 0.3, -0.75))
	-- El lomo plateado de los machos adultos.
	local silver = fur:Lerp(Color3.fromRGB(215, 215, 220), 0.5)
	glue(rig, torso, piece(rig, "Saddle", "Oval", Vector3.new(1.7, 0.55, 1.5), silver), CFrame.new(0, 0.5, 0.55) * tilt)

	local head = piece(rig, "Head", "Ball", Vector3.one * 1.2, fur)
	joint(rig, torso, head, "Neck", CFrame.new(0, 0.45, -1.75), Vector3.new(0, 0.4, -1.25))
	glue(rig, head, piece(rig, "Crest", "Oval", Vector3.new(0.75, 0.9, 1), fur), CFrame.new(0, 0.95, -1.65))
	glue(rig, head, piece(rig, "Face", "Oval", Vector3.new(0.95, 0.9, 0.4), skin), CFrame.new(0, 0.38, -2.22))
	glue(rig, head, piece(rig, "Brow", "Oval", Vector3.new(1, 0.25, 0.4), darker(skin, 0.3)), CFrame.new(0, 0.68, -2.3))
	glue(rig, head, piece(rig, "Muzzle", "Oval", Vector3.new(0.6, 0.4, 0.35), skin), CFrame.new(0, 0.2, -2.38))
	eyes(rig, head, 0.2, 0.55, -2.4, 0.14)
	for side = -1, 1, 2 do
		glue(rig, head, piece(rig, "Ear", "Ball", Vector3.one * 0.28, skin), CFrame.new(side * 0.6, 0.5, -1.75))
	end

	groundLimbs(
		rig,
		torso,
		fur,
		darker(skin, 0.15),
		{ size = Vector3.new(0.8, 2.3, 0.85), x = 1.05, z = -1.05 },
		{ size = Vector3.new(0.8, 1.55, 0.85), x = 0.75, z = 1.15 }
	)
end

-- Chimpancé: más esbelto, pelo negro, cara clara con el hocico salido, cejas marcadas y orejas
-- grandes. bodyColor = pelo, faceColor = piel.
local function chimpanzee(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local skin = definition.faceColor
	local torso = piece(rig, "Torso", "Oval", Vector3.new(1.45, 1.35, 2.2), fur)
	joint(
		rig,
		rig.root,
		torso,
		"RootJoint",
		CFrame.new(0, -0.1, 0.3) * CFrame.Angles(math.rad(20), 0, 0),
		Vector3.new(0, -0.1, 0.3)
	)
	glue(rig, torso, piece(rig, "Chest", "Oval", Vector3.new(1.6, 1.2, 1.1), fur), CFrame.new(0, 0.15, -0.55))

	local head = piece(rig, "Head", "Ball", Vector3.one * 1.05, fur)
	joint(rig, torso, head, "Neck", CFrame.new(0, 0.5, -1.35), Vector3.new(0, 0.35, -0.9))
	glue(rig, head, piece(rig, "Face", "Oval", Vector3.new(0.8, 0.8, 0.45), skin), CFrame.new(0, 0.45, -1.75))
	glue(rig, head, piece(rig, "Muzzle", "Oval", Vector3.new(0.62, 0.48, 0.5), skin), CFrame.new(0, 0.22, -1.9))
	glue(
		rig,
		head,
		piece(rig, "Brow", "Oval", Vector3.new(0.82, 0.2, 0.32), darker(skin, 0.2)),
		CFrame.new(0, 0.7, -1.82)
	)
	eyes(rig, head, 0.17, 0.58, -1.92, 0.13)
	for side = -1, 1, 2 do
		glue(
			rig,
			head,
			piece(rig, "Ear", "Oval", Vector3.new(0.14, 0.5, 0.42), skin),
			CFrame.new(side * 0.56, 0.52, -1.3)
		)
	end

	groundLimbs(
		rig,
		torso,
		fur,
		skin,
		{ size = Vector3.new(0.48, 2.05, 0.52), x = 0.82, z = -0.8 },
		{ size = Vector3.new(0.52, 1.5, 0.56), x = 0.55, z = 1.05 }
	)
end

-- Orangután: pelo largo y rojizo, brazos larguísimos con flecos de pelo, piernas cortas, barriga
-- y, en la cara, las grandes almohadillas de las mejillas y el saco de la garganta de los machos.
-- bodyColor = pelo, faceColor = piel.
local function orangutan(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local skin = definition.faceColor
	local tilt = CFrame.Angles(math.rad(25), 0, 0)
	local torso = piece(rig, "Torso", "Oval", Vector3.new(1.75, 1.65, 2), fur)
	joint(rig, rig.root, torso, "RootJoint", CFrame.new(0, 0.05, 0.3) * tilt, Vector3.new(0, 0.05, 0.3))
	glue(
		rig,
		torso,
		piece(rig, "Belly", "Oval", Vector3.new(1.5, 1.2, 1.4), darker(fur, 0.15)),
		CFrame.new(0, -0.35, 0.45) * tilt
	)
	local shag = fur:Lerp(Color3.new(1, 1, 1), 0.08)
	glue(rig, torso, piece(rig, "Shag", "Oval", Vector3.new(1.95, 0.7, 2.1), shag), CFrame.new(0, 0.62, 0.25) * tilt)

	local head = piece(rig, "Head", "Ball", Vector3.one * 1, fur)
	joint(rig, torso, head, "Neck", CFrame.new(0, 0.7, -1.15), Vector3.new(0, 0.5, -0.7))
	glue(rig, head, piece(rig, "Crown", "Oval", Vector3.new(0.95, 0.55, 0.95), fur), CFrame.new(0, 1.05, -1.05))
	glue(
		rig,
		head,
		piece(rig, "Flanges", "Oval", Vector3.new(2, 1.35, 0.25), darker(skin, 0.2)),
		CFrame.new(0, 0.68, -1.5)
	)
	glue(rig, head, piece(rig, "Face", "Oval", Vector3.new(0.75, 0.9, 0.35), skin), CFrame.new(0, 0.68, -1.68))
	local lip = skin:Lerp(Color3.new(1, 1, 1), 0.15)
	glue(rig, head, piece(rig, "Muzzle", "Oval", Vector3.new(0.5, 0.35, 0.3), lip), CFrame.new(0, 0.42, -1.82))
	glue(rig, head, piece(rig, "ThroatSac", "Oval", Vector3.new(0.95, 0.75, 0.75), skin), CFrame.new(0, 0.15, -1.4))
	eyes(rig, head, 0.14, 0.85, -1.84, 0.11)

	groundLimbs(
		rig,
		torso,
		fur,
		skin,
		{ size = Vector3.new(0.58, 2.45, 0.62), x = 1, z = -0.7 },
		{ size = Vector3.new(0.52, 1.35, 0.56), x = 0.62, z = 1 }
	)
	-- Flecos de pelo largo colgando de los brazos.
	for side = -1, 1, 2 do
		local arm = rig.model:FindFirstChild(`{sideName(side)} Arm`) :: BasePart
		glue(
			rig,
			arm,
			piece(rig, "ArmHair", "Oval", Vector3.new(0.3, 1.6, 0.7), fur),
			CFrame.new(side * 1.28, -0.45, -0.65)
		)
	end
end

-- Monos con cola a cuatro patas: cuerpo, cabeza, extremidades hasta el suelo y la cola, que cae
-- con "droop" grados (negativo: levantada) y puede doblarse al final ("curl" grados; positivo: hacia
-- arriba). Devuelve el torso y la cabeza para añadir los rasgos de cada especie.
type TailSpec = {
	base: Vector3,
	length: number,
	thickness: number,
	droop: number,
	color: Color3?,
	curl: { length: number, angle: number, color: Color3? }?,
}

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

local function tail(rig: Rig, torso: BasePart, spec: TailSpec, fur: Color3)
	local color = spec.color or fur
	local droop = math.rad(spec.droop)
	local direction = Vector3.new(0, -math.sin(droop), math.cos(droop))
	local thickness = Vector3.new(spec.thickness, spec.thickness, 0)
	local part = piece(rig, "Tail", "Oval", thickness + Vector3.new(0, 0, spec.length), color)
	joint(
		rig,
		torso,
		part,
		"TailJoint",
		CFrame.new(spec.base + direction * spec.length / 2) * CFrame.Angles(droop, 0, 0),
		spec.base
	)
	local curl = spec.curl
	if curl then
		local bend = droop - math.rad(curl.angle)
		local bendDirection = Vector3.new(0, -math.sin(bend), math.cos(bend))
		local start = spec.base + direction * (spec.length - spec.thickness)
		glue(
			rig,
			part,
			piece(rig, "TailTip", "Oval", thickness + Vector3.new(0, 0, curl.length), curl.color or color),
			CFrame.new(start + bendDirection * curl.length / 2) * CFrame.Angles(bend, 0, 0)
		)
	end
end

local function tailedMonkey(rig: Rig, spec: BodySpec): (BasePart, BasePart)
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
	joint(rig, torso, head, "Neck", CFrame.new(0, headSpec.y, headSpec.z), spec.neck)
	groundLimbs(rig, torso, spec.fur, spec.paws, spec.arm, spec.leg)
	tail(rig, torso, spec.tail, spec.fur)
	return torso, head
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

-- Aullador rojo: robusto y rojizo, cara oscura y una gran barba sobre la garganta (su caja de
-- resonancia). Cola prensil con la punta colgando.
local function howler(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local skin = definition.faceColor
	local torso, head = tailedMonkey(rig, {
		fur = fur,
		paws = skin,
		torso = { size = Vector3.new(1.3, 1.2, 2.2), y = -0.3, z = 0.2, tilt = 8 },
		head = { diameter = 1, y = 0.25, z = -1.25 },
		neck = Vector3.new(0, -0.05, -0.8),
		arm = { size = Vector3.new(0.32, 1.45, 0.36), x = 0.5, z = -0.55 },
		leg = { size = Vector3.new(0.36, 1.4, 0.4), x = 0.45, z = 0.95 },
		tail = {
			base = Vector3.new(0, -0.1, 1.25),
			length = 2.6,
			thickness = 0.22,
			droop = 20,
			curl = { length = 0.8, angle = -70 },
		},
	})
	feature(rig, head, "Face", Vector3.new(0.7, 0.7, 0.35), skin, CFrame.new(0, 0.2, -1.62))
	feature(rig, head, "Muzzle", Vector3.new(0.5, 0.4, 0.35), skin, CFrame.new(0, 0.02, -1.72))
	feature(rig, head, "Beard", Vector3.new(0.75, 0.6, 0.6), darker(fur, 0.25), CFrame.new(0, -0.25, -1.45))
	eyes(rig, head, 0.15, 0.32, -1.76, 0.11)
	feature(rig, torso, "Shoulders", Vector3.new(1.35, 0.9, 1), fur, CFrame.new(0, -0.1, -0.5))
end

-- Capuchino de cara blanca: cuerpo oscuro, cara, pecho y hombros claros, gorro negro y cara rosada.
-- Cola prensil con la punta enroscada hacia abajo.
local function capuchin(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local cream = definition.faceColor
	local skin = Color3.fromRGB(225, 170, 150)
	local torso, head = tailedMonkey(rig, {
		fur = fur,
		paws = darker(fur, 0.3),
		torso = { size = Vector3.new(1, 0.95, 1.8), y = -0.35, z = 0.15, tilt = 6 },
		head = { diameter = 1, y = 0.25, z = -1.15, color = cream },
		neck = Vector3.new(0, -0.05, -0.75),
		arm = { size = Vector3.new(0.28, 1.4, 0.3), x = 0.4, z = -0.5 },
		leg = { size = Vector3.new(0.32, 1.35, 0.34), x = 0.4, z = 0.8 },
		tail = {
			base = Vector3.new(0, -0.15, 1),
			length = 2.2,
			thickness = 0.2,
			droop = -15,
			curl = { length = 0.7, angle = -100 },
		},
	})
	feature(rig, torso, "Chest", Vector3.new(1.05, 0.8, 0.9), cream, CFrame.new(0, -0.15, -0.55))
	feature(rig, head, "Cap", Vector3.new(1.02, 0.5, 0.95), Color3.fromRGB(30, 25, 22), CFrame.new(0, 0.58, -1.02))
	feature(rig, head, "Face", Vector3.new(0.55, 0.6, 0.25), skin, CFrame.new(0, 0.18, -1.6))
	feature(
		rig,
		head,
		"Muzzle",
		Vector3.new(0.38, 0.28, 0.25),
		skin:Lerp(Color3.new(1, 1, 1), 0.2),
		CFrame.new(0, 0.02, -1.7)
	)
	eyes(rig, head, 0.13, 0.28, -1.72, 0.12)
	for side = -1, 1, 2 do
		glue(rig, head, piece(rig, "Ear", "Ball", Vector3.one * 0.22, cream), CFrame.new(side * 0.48, 0.25, -1.1))
	end
end

-- Marimonda (mono araña): negra, con brazos y piernas larguísimos y finos, barriga y una cola
-- prensil muy larga levantada en forma de S.
local function spiderMonkey(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local skin = definition.faceColor
	local torso, head = tailedMonkey(rig, {
		fur = fur,
		paws = skin,
		torso = { size = Vector3.new(0.95, 0.95, 1.6), y = -0.05, z = 0.15, tilt = 15 },
		head = { diameter = 0.85, y = 0.5, z = -0.95 },
		neck = Vector3.new(0, 0.25, -0.6),
		arm = { size = Vector3.new(0.22, 2.2, 0.24), x = 0.45, z = -0.45 },
		leg = { size = Vector3.new(0.24, 1.95, 0.26), x = 0.4, z = 0.7 },
		tail = {
			base = Vector3.new(0, 0.1, 0.9),
			length = 3.4,
			thickness = 0.15,
			droop = -35,
			curl = { length = 0.9, angle = -110 },
		},
	})
	feature(rig, torso, "Belly", Vector3.new(0.85, 0.75, 1), darker(fur, 0.2), CFrame.new(0, -0.3, 0.25))
	feature(rig, head, "Face", Vector3.new(0.55, 0.55, 0.25), skin, CFrame.new(0, 0.45, -1.32))
	feature(rig, head, "Muzzle", Vector3.new(0.35, 0.25, 0.22), skin, CFrame.new(0, 0.32, -1.42))
	eyes(rig, head, 0.12, 0.54, -1.44, 0.1)
end

-- Tití del Chocó (tamarino de Geoffroy): diminuto, cabeza oscura con una cresta blanca en forma de
-- cuña, nuca rojiza, garganta y pecho blancos, lomo moteado y cola larga que cuelga.
local function tamarin(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local white = definition.faceColor
	local dark = Color3.fromRGB(40, 35, 30)
	local torso, head = tailedMonkey(rig, {
		fur = fur,
		paws = dark,
		torso = { size = Vector3.new(0.95, 0.85, 1.5), y = -0.45, z = 0.15, tilt = 5 },
		head = { diameter = 1, y = 0.15, z = -1, color = dark },
		neck = Vector3.new(0, -0.2, -0.6),
		arm = { size = Vector3.new(0.25, 1.25, 0.27), x = 0.38, z = -0.45 },
		leg = { size = Vector3.new(0.28, 1.25, 0.3), x = 0.38, z = 0.7 },
		tail = {
			base = Vector3.new(0, -0.3, 0.9),
			length = 2.6,
			thickness = 0.16,
			droop = 30,
			curl = { length = 0.6, angle = -20, color = dark },
		},
	})
	feature(rig, torso, "Mottle", Vector3.new(0.7, 0.25, 0.9), darker(fur, 0.45), CFrame.new(0, -0.05, 0.3))
	feature(rig, torso, "Chest", Vector3.new(0.8, 0.6, 0.8), white, CFrame.new(0, -0.55, -0.35))
	feature(rig, head, "Crest", Vector3.new(0.35, 0.55, 0.9), white, CFrame.new(0, 0.6, -1))
	feature(rig, head, "Nape", Vector3.new(0.8, 0.6, 0.5), Color3.fromRGB(170, 80, 40), CFrame.new(0, 0.15, -0.6))
	feature(rig, head, "Throat", Vector3.new(0.6, 0.45, 0.4), white, CFrame.new(0, -0.2, -1.25))
	for side = -1, 1, 2 do
		glue(
			rig,
			head,
			piece(rig, "Eye", "Ball", Vector3.one * 0.16, Color3.fromRGB(120, 70, 30)),
			CFrame.new(side * 0.17, 0.22, -1.47)
		)
	end
end

-- Marteja (mono nocturno): cabeza redonda con una máscara clara, rayas oscuras y unos ojos enormes
-- que brillan en la oscuridad; pecho anaranjado y cola peluda con la punta negra.
local function nightMonkey(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local pale = definition.faceColor
	local stripe = Color3.fromRGB(45, 38, 32)
	local torso, head = tailedMonkey(rig, {
		fur = fur,
		paws = darker(fur, 0.3),
		torso = { size = Vector3.new(1, 0.95, 1.7), y = -0.35, z = 0.15, tilt = 6 },
		head = { diameter = 1, y = 0.25, z = -1.1 },
		neck = Vector3.new(0, -0.1, -0.7),
		arm = { size = Vector3.new(0.28, 1.4, 0.3), x = 0.4, z = -0.5 },
		leg = { size = Vector3.new(0.32, 1.4, 0.34), x = 0.4, z = 0.8 },
		tail = {
			base = Vector3.new(0, -0.15, 1),
			length = 2.6,
			thickness = 0.3,
			droop = 25,
			curl = { length = 0.8, angle = -10, color = stripe },
		},
	})
	feature(
		rig,
		torso,
		"Chest",
		Vector3.new(0.85, 0.6, 0.9),
		Color3.fromRGB(215, 160, 100),
		CFrame.new(0, -0.55, -0.35)
	)
	feature(rig, head, "Face", Vector3.new(0.75, 0.65, 0.28), pale, CFrame.new(0, 0.25, -1.5))
	feature(rig, head, "Stripe", Vector3.new(0.08, 0.4, 0.06), stripe, CFrame.new(0, 0.42, -1.66))
	for side = -1, 1, 2 do
		feature(
			rig,
			head,
			"Stripe",
			Vector3.new(0.08, 0.35, 0.06),
			stripe,
			CFrame.new(side * 0.33, 0.38, -1.6) * CFrame.Angles(0, side * math.rad(30), side * math.rad(-20))
		)
		glue(
			rig,
			head,
			piece(rig, "Eye", "Ball", Vector3.one * 0.3, Color3.fromRGB(255, 170, 60), Enum.Material.Neon),
			CFrame.new(side * 0.18, 0.28, -1.62)
		)
		glue(
			rig,
			head,
			piece(rig, "Pupil", "Ball", Vector3.one * 0.14, EYE_COLOR),
			CFrame.new(side * 0.18, 0.28, -1.74)
		)
	end
	feature(rig, head, "Muzzle", Vector3.new(0.3, 0.2, 0.2), stripe, CFrame.new(0, 0.06, -1.66))
end

-- Mandril: grande y musculoso, hocico largo con la nariz roja y las mejillas azules, barba
-- amarilla, trasero de colores y una cola muy corta.
local function mandrill(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local red = definition.faceColor
	local blue = Color3.fromRGB(60, 110, 200)
	local torso, head = tailedMonkey(rig, {
		fur = fur,
		paws = Color3.fromRGB(50, 45, 40),
		torso = { size = Vector3.new(1.5, 1.35, 2.3), y = -0.1, z = 0.25, tilt = 14 },
		head = { diameter = 1.1, y = 0.4, z = -1.35 },
		neck = Vector3.new(0, 0.2, -0.85),
		arm = { size = Vector3.new(0.48, 1.95, 0.52), x = 0.7, z = -0.75 },
		leg = { size = Vector3.new(0.5, 1.6, 0.55), x = 0.55, z = 1.05 },
		tail = { base = Vector3.new(0, 0, 1.4), length = 0.5, thickness = 0.2, droop = -20 },
	})
	feature(rig, torso, "Shoulders", Vector3.new(1.7, 1.2, 1.2), fur, CFrame.new(0, 0.15, -0.6))
	feature(rig, torso, "Rump", Vector3.new(0.9, 0.8, 0.35), Color3.fromRGB(120, 90, 200), CFrame.new(0, -0.35, 1.45))
	feature(rig, head, "Snout", Vector3.new(0.6, 0.55, 0.95), blue, CFrame.new(0, 0.25, -1.95))
	feature(rig, head, "NoseRidge", Vector3.new(0.22, 0.2, 0.95), red, CFrame.new(0, 0.48, -1.98))
	feature(rig, head, "Nose", Vector3.new(0.3, 0.22, 0.15), red, CFrame.new(0, 0.42, -2.42))
	feature(rig, head, "Beard", Vector3.new(0.8, 0.45, 0.6), Color3.fromRGB(220, 190, 90), CFrame.new(0, 0, -1.75))
	feature(rig, head, "Brow", Vector3.new(0.8, 0.22, 0.3), darker(fur, 0.3), CFrame.new(0, 0.75, -1.75))
	for side = -1, 1, 2 do
		glue(
			rig,
			head,
			piece(rig, "Eye", "Ball", Vector3.one * 0.12, Color3.fromRGB(170, 110, 40)),
			CFrame.new(side * 0.2, 0.62, -1.83)
		)
	end
end

-- Macaco (rhesus): pelo pardo grisáceo, cuartos traseros anaranjados, cara y orejas rosadas, cejas
-- marcadas y cola mediana.
local function macaque(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local skin = definition.faceColor
	local torso, head = tailedMonkey(rig, {
		fur = fur,
		paws = darker(skin, 0.15),
		torso = { size = Vector3.new(1.2, 1.1, 2), y = -0.25, z = 0.2, tilt = 8 },
		head = { diameter = 0.95, y = 0.3, z = -1.2 },
		neck = Vector3.new(0, 0, -0.8),
		arm = { size = Vector3.new(0.32, 1.55, 0.35), x = 0.5, z = -0.6 },
		leg = { size = Vector3.new(0.36, 1.5, 0.4), x = 0.45, z = 0.95 },
		tail = { base = Vector3.new(0, -0.05, 1.15), length = 1.2, thickness = 0.2, droop = 30 },
	})
	feature(
		rig,
		torso,
		"Haunches",
		Vector3.new(1.15, 0.9, 1),
		Color3.fromRGB(175, 125, 85),
		CFrame.new(0, -0.25, 0.85) * CFrame.Angles(math.rad(8), 0, 0)
	)
	feature(rig, head, "Face", Vector3.new(0.62, 0.6, 0.3), skin, CFrame.new(0, 0.27, -1.58))
	feature(rig, head, "Muzzle", Vector3.new(0.42, 0.32, 0.3), skin, CFrame.new(0, 0.1, -1.7))
	feature(rig, head, "Brow", Vector3.new(0.62, 0.15, 0.22), fur, CFrame.new(0, 0.46, -1.65))
	eyes(rig, head, 0.15, 0.35, -1.72, 0.11)
	for side = -1, 1, 2 do
		feature(rig, head, "Ear", Vector3.new(0.1, 0.28, 0.22), skin, CFrame.new(side * 0.48, 0.35, -1.15))
	end
end

-- Babuino: hocico largo como de perro, melena sobre los hombros (más grande en el alfa), callos
-- rosados en el trasero y la cola "rota": sube y luego cae.
local function baboon(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local skin = definition.faceColor
	local torso, head = tailedMonkey(rig, {
		fur = fur,
		paws = skin,
		torso = { size = Vector3.new(1.35, 1.2, 2.2), y = -0.15, z = 0.25, tilt = 12 },
		head = { diameter = 0.95, y = 0.35, z = -1.3 },
		neck = Vector3.new(0, 0.1, -0.85),
		arm = { size = Vector3.new(0.4, 1.85, 0.44), x = 0.62, z = -0.75 },
		leg = { size = Vector3.new(0.42, 1.6, 0.46), x = 0.5, z = 1 },
		tail = {
			base = Vector3.new(0, 0.05, 1.3),
			length = 0.7,
			thickness = 0.2,
			droop = -45,
			curl = { length = 1.4, angle = -120 },
		},
	})
	feature(
		rig,
		torso,
		"Mane",
		Vector3.new(1.6, 1.3, 1.3),
		fur:Lerp(Color3.new(1, 1, 1), 0.1),
		CFrame.new(0, 0.2, -0.55)
	)
	feature(
		rig,
		torso,
		"Callus",
		Vector3.new(0.7, 0.55, 0.25),
		Color3.fromRGB(200, 110, 110),
		CFrame.new(0, -0.5, 1.35)
	)
	feature(rig, head, "Muzzle", Vector3.new(0.5, 0.45, 0.95), skin, CFrame.new(0, 0.18, -1.85))
	feature(rig, head, "Nose", Vector3.new(0.3, 0.22, 0.12), darker(skin, 0.3), CFrame.new(0, 0.25, -2.3))
	feature(rig, head, "Brow", Vector3.new(0.7, 0.18, 0.3), darker(skin, 0.2), CFrame.new(0, 0.55, -1.68))
	for side = -1, 1, 2 do
		glue(
			rig,
			head,
			piece(rig, "Eye", "Ball", Vector3.one * 0.11, Color3.fromRGB(150, 100, 40)),
			CFrame.new(side * 0.16, 0.45, -1.75)
		)
		glue(rig, head, piece(rig, "Ear", "Ball", Vector3.one * 0.2, skin), CFrame.new(side * 0.45, 0.45, -1.2))
	end
end

-- Mono de cola larga (macaco cangrejero): pardo grisáceo, patillas claras alrededor de la cara,
-- una cresta en la coronilla y una cola larguísima.
local function longTailedMacaque(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local pale = definition.faceColor
	local skin = Color3.fromRGB(200, 160, 140)
	local _, head = tailedMonkey(rig, {
		fur = fur,
		paws = skin,
		torso = { size = Vector3.new(1.1, 1, 1.9), y = -0.3, z = 0.2, tilt = 6 },
		head = { diameter = 0.9, y = 0.22, z = -1.15 },
		neck = Vector3.new(0, -0.05, -0.75),
		arm = { size = Vector3.new(0.3, 1.5, 0.33), x = 0.45, z = -0.55 },
		leg = { size = Vector3.new(0.34, 1.45, 0.37), x = 0.42, z = 0.9 },
		tail = {
			base = Vector3.new(0, -0.1, 1.1),
			length = 3.2,
			thickness = 0.17,
			droop = 22,
			curl = { length = 0.7, angle = 40 },
		},
	})
	feature(rig, head, "Whiskers", Vector3.new(0.95, 0.55, 0.35), pale, CFrame.new(0, 0.12, -1.45))
	feature(rig, head, "Face", Vector3.new(0.55, 0.55, 0.28), skin, CFrame.new(0, 0.2, -1.5))
	feature(rig, head, "Muzzle", Vector3.new(0.35, 0.25, 0.25), skin, CFrame.new(0, 0.05, -1.62))
	feature(rig, head, "Crest", Vector3.new(0.25, 0.35, 0.5), fur, CFrame.new(0, 0.7, -1.1))
	eyes(rig, head, 0.13, 0.28, -1.63, 0.1)
end

-- Gibón: simio sin cola que en el suelo anda erguido, con los larguísimos brazos en alto para
-- equilibrarse. Pelo oscuro, cara negra rodeada de un anillo claro y manos claras.
local function gibbon(rig: Rig, definition: Monkeys.MonkeyDefinition)
	local fur = definition.bodyColor
	local pale = definition.faceColor
	local torso = piece(rig, "Torso", "Oval", Vector3.new(1, 1.5, 0.8), fur)
	joint(rig, rig.root, torso, "RootJoint", CFrame.new(0, -0.05, 0), Vector3.new(0, -0.05, 0))
	local head = piece(rig, "Head", "Ball", Vector3.one * 0.85, fur)
	joint(rig, torso, head, "Neck", CFrame.new(0, 1.05, -0.05), Vector3.new(0, 0.7, 0))
	feature(rig, head, "FaceRing", Vector3.new(0.68, 0.72, 0.2), pale, CFrame.new(0, 1.02, -0.38))
	feature(rig, head, "Face", Vector3.new(0.5, 0.55, 0.25), Color3.fromRGB(25, 22, 20), CFrame.new(0, 1.02, -0.42))
	for side = -1, 1, 2 do
		glue(
			rig,
			head,
			piece(rig, "Eye", "Ball", Vector3.one * 0.1, Color3.fromRGB(110, 70, 40)),
			CFrame.new(side * 0.11, 1.1, -0.53)
		)
		-- Brazos en alto, abiertos 40° desde la vertical, con las manos claras.
		local shoulder = Vector3.new(side * 0.5, 0.5, 0)
		local angle = -side * math.rad(40)
		local up = Vector3.new(-math.sin(angle), math.cos(angle), 0)
		local arm = piece(rig, `{sideName(side)} Arm`, "Oval", Vector3.new(0.24, 2.4, 0.26), fur)
		joint(
			rig,
			torso,
			arm,
			`{sideName(side)} Shoulder`,
			CFrame.new(shoulder + up * 1.08) * CFrame.Angles(0, 0, angle),
			shoulder
		)
		feature(
			rig,
			arm,
			"Hand",
			Vector3.new(0.28, 0.4, 0.32),
			pale,
			CFrame.new(shoulder + up * 2.3) * CFrame.Angles(0, 0, angle)
		)

		local leg = piece(rig, `{sideName(side)} Leg`, "Oval", Vector3.new(0.32, 1.3, 0.34), fur)
		joint(
			rig,
			torso,
			leg,
			`{sideName(side)} Hip`,
			CFrame.new(side * 0.3, GROUND + 0.65, 0.05),
			Vector3.new(side * 0.3, -0.75, 0.05)
		)
		feature(
			rig,
			leg,
			"Foot",
			Vector3.new(0.3, 0.2, 0.55),
			darker(fur, 0.2),
			CFrame.new(side * 0.3, GROUND + 0.1, -0.12)
		)
	end
end

local BUILDERS: { [string]: (rig: Rig, definition: Monkeys.MonkeyDefinition) -> () } = {
	MonoArdilla = squirrelMonkey,
	AulladorRojo = howler,
	CapuchinoLadron = capuchin,
	Marimonda = spiderMonkey,
	Titi = tamarin,
	Marteja = nightMonkey,
	Mandril = mandrill,
	Macaco = macaque,
	Gibon = gibbon,
	Babuino = baboon,
	ColaLarga = longTailedMacaque,
	Gorila = gorilla,
	Chimpance = chimpanzee,
	Orangutan = orangutan,
}

---------------------------------------------------------------------------------------------------
-- Detalles de los jefes, sobre el modelo de su especie base y en sus mismas coordenadas.

local function partNamed(rig: Rig, name: string): BasePart
	return rig.model:FindFirstChild(name) :: BasePart
end

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
	-- Orangután del Manglar: musgo en el lomo y en la cabeza y una liana cruzada.
	OrangutanDelManglar = function(rig)
		local moss = Color3.fromRGB(85, 120, 50)
		local torso = partNamed(rig, "Torso")
		local head = partNamed(rig, "Head")
		for _, patch in
			{
				{ anchor = torso, size = Vector3.new(1, 0.35, 1.1), at = CFrame.new(0.45, 1, 0) },
				{ anchor = torso, size = Vector3.new(0.8, 0.3, 0.9), at = CFrame.new(-0.5, 0.85, 0.65) },
				{ anchor = head, size = Vector3.new(0.55, 0.2, 0.55), at = CFrame.new(0.1, 1.3, -1) },
			}
		do
			glue(rig, patch.anchor, piece(rig, "Moss", "Oval", patch.size, moss, Enum.Material.Grass), patch.at)
		end
		glue(
			rig,
			torso,
			piece(rig, "Vine", "Oval", Vector3.new(0.14, 0.14, 2.8), Color3.fromRGB(60, 95, 40)),
			CFrame.new(0, 0.9, 0.2) * CFrame.Angles(math.rad(25), math.rad(35), 0)
		)
	end,

	-- Chimpancé Caudillo: cinta roja con plumas, pinturas de guerra y collar de colmillos.
	ChimpanceCaudillo = function(rig)
		local head = partNamed(rig, "Head")
		local torso = partNamed(rig, "Torso")
		glue(
			rig,
			head,
			piece(
				rig,
				"Headband",
				"Cylinder",
				Vector3.new(0.22, 1.12, 1.12),
				Color3.fromRGB(170, 30, 25),
				Enum.Material.Fabric
			),
			CFrame.new(0, 0.8, -1.35) * CFrame.Angles(0, 0, math.rad(90))
		)
		local feathers = { Color3.fromRGB(230, 60, 40), Color3.fromRGB(245, 200, 60), Color3.fromRGB(240, 240, 235) }
		for index, angle in { -0.8, -0.4, 0, 0.4, 0.8 } do
			glue(
				rig,
				head,
				piece(rig, "Feather", "Oval", Vector3.new(0.12, 0.8, 0.26), feathers[(index - 1) % 3 + 1]),
				CFrame.new(math.sin(angle) * 0.45, 1.2, -1.35 + math.cos(angle) * 0.35)
					* CFrame.Angles(math.rad(-20), 0, -angle * 0.6)
			)
		end
		for side = -1, 1, 2 do
			for stripe = 0, 1 do
				glue(
					rig,
					head,
					piece(rig, "WarPaint", "Oval", Vector3.new(0.07, 0.3, 0.06), Color3.fromRGB(200, 30, 30)),
					CFrame.new(side * (0.24 + stripe * 0.08), 0.42, -1.92 + stripe * 0.03)
						* CFrame.Angles(0, side * math.rad(35), 0)
				)
			end
		end
		for index = -2, 2 do
			local x = index * 0.2
			glue(
				rig,
				torso,
				piece(rig, "Fang", "Oval", Vector3.new(0.12, 0.3, 0.12), Color3.fromRGB(240, 235, 215)),
				CFrame.new(x, 0.05 - math.abs(x) * 0.3, -1.12) * CFrame.Angles(0, 0, -x * 0.8)
			)
		end
	end,

	-- Gorila Albino: ojos rojizos que brillan en la oscuridad y cristales de cueva en el lomo.
	GorilaAlbino = function(rig)
		glowEyes(rig, Color3.fromRGB(235, 80, 90))
		local torso = partNamed(rig, "Torso")
		local crystal = Color3.fromRGB(120, 220, 255)
		for index, spot in
			{
				CFrame.new(0.5, 0.95, -0.2) * CFrame.Angles(0.3, 0, -0.4),
				CFrame.new(-0.5, 0.95, -0.15) * CFrame.Angles(0.2, 0, 0.5),
				CFrame.new(0, 1.05, 0.3) * CFrame.Angles(-0.2, 0.4, 0),
				CFrame.new(0.35, 0.75, 0.95) * CFrame.Angles(-0.4, 0, -0.3),
				CFrame.new(-0.35, 0.75, 0.95) * CFrame.Angles(-0.4, 0, 0.3),
			}
		do
			local size = Vector3.new(0.3, 1.1 - index * 0.08, 0.3)
			local shard = piece(rig, "Crystal", "Block", size, crystal, Enum.Material.Neon)
			glue(rig, torso, shard, spot)
			if index == 3 then
				glow(rig, shard, crystal, 9, 1.5)
			end
		end
	end,

	-- Gorila de Ceniza: grietas de lava en el cuerpo, ojos de fuego, ascuas y humo.
	GorilaDeCeniza = function(rig)
		local lava = Color3.fromRGB(255, 110, 30)
		glowEyes(rig, Color3.fromRGB(255, 170, 60))
		local torso = partNamed(rig, "Torso")
		for _, crack in
			{
				CFrame.new(0.4, 0.95, -0.3) * CFrame.Angles(0, 0.5, 0),
				CFrame.new(-0.35, 0.95, 0.25) * CFrame.Angles(0, -0.4, 0),
				CFrame.new(0.1, 0.85, 0.9) * CFrame.Angles(0.3, 1.2, 0),
				CFrame.new(-0.7, 0.55, -0.6) * CFrame.Angles(0, -0.9, 0.5),
				CFrame.new(0.75, 0.5, -0.55) * CFrame.Angles(0, 0.9, -0.5),
			}
		do
			glue(
				rig,
				torso,
				piece(rig, "LavaCrack", "Oval", Vector3.new(0.12, 0.08, 1), lava, Enum.Material.Neon),
				crack
			)
		end
		for side = -1, 1, 2 do
			glue(
				rig,
				partNamed(rig, `{sideName(side)} Arm`),
				piece(rig, "LavaCrack", "Oval", Vector3.new(0.08, 0.9, 0.12), lava, Enum.Material.Neon),
				CFrame.new(side * 1.44, -0.6, -1.05) * CFrame.Angles(0.3, 0, 0)
			)
		end
		glow(rig, torso, lava, 12, 2)

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

	local rig: Rig = { model = model, root = root, scale = s }
	local builder = BUILDERS[speciesId] or genericMonkey
	builder(rig, definition)
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

return MonkeyModels
