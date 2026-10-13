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
-- Cada especie puede tener su propio constructor (BUILDERS); las demás usan el genérico.
-- Cada especie se construye una vez como plantilla y los monos son copias (MonkeyModels.spawn).
-- El Humanoid lo mueve como a un personaje.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)

-- Las posiciones de los constructores son respecto a la raíz, a escala 1, con la cara hacia -Z.
-- La raíz está a rootHeight sobre el suelo: con escala 1, el suelo queda en Y = -1.9.
type Rig = { model: Model, root: BasePart, scale: number }

type Shape = "Block" | "Ball" | "Oval"

local MonkeyModels = {}

local EYE_COLOR = Color3.fromRGB(20, 15, 10)

local templates: { [string]: Model } = {}

local function piece(rig: Rig, name: string, shape: Shape, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Oval" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Size = size * rig.scale
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
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

local BUILDERS: { [string]: (rig: Rig, definition: Monkeys.MonkeyDefinition) -> () } = {
	MonoArdilla = squirrelMonkey,
}

-- Altura de la raíz sobre el suelo para que las patas lo toquen (ver HipHeight).
function MonkeyModels.rootHeight(scale: number): number
	return 1.9 * scale
end

-- Construye un mono nuevo. "ground" es el punto del suelo donde aparece. Los jefes lo usan con su
-- propio aspecto; los monos normales salen de MonkeyModels.spawn.
function MonkeyModels.build(speciesId: string, definition: Monkeys.MonkeyDefinition, ground: Vector3): Model
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

	local builder = BUILDERS[speciesId] or genericMonkey
	builder({ model = model, root = root, scale = s }, definition)

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
