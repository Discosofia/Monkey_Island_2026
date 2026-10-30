--!strict
-- Rig de los brazos en primera persona del Laboratorio (Fase 19, W10). Lo monta FirstPersonController en
-- ArmaEnPrimeraPersona: un AnimationController con un Animator y brazos de bloques unidos por Motor6D, para que
-- las poses sean AnimationTrack (ViewModelAnimations; nunca articulaciones giradas por código).
--
-- Jerarquía (el nombre de la pieza es el de la pose de la animación; el de la Motor6D, el de abajo):
--   Root (invisible, anclada: el controlador la pega a la cámara)
--     RightShoulder -> RightUpperArm -> RightElbow -> RightLowerArm -> RightHand (Motor6D) -> RightHand (bloque)
--       RightHand -> WeaponGrip -> Handle (el arma, con sus piezas soldadas por WeldConstraint)
--     LeftShoulder  -> LeftUpperArm  -> LeftElbow  -> LeftLowerArm  -> LeftHand (Motor6D) -> LeftHand (bloque)
-- Más un puño por brazo (RightCuff, LeftCuff) soldado al antebrazo. En total 9 piezas sin contar el arma
-- (tope: Config.Budgets.Models.LabViewModelArms).
--
-- El espacio de Root es el de la cámara (X derecha, Y arriba, -Z delante) y su origen es el punto de la
-- empuñadura. El reposo es la pose «de cadera»; las animaciones son giros (y desplazamientos) sobre él. Los
-- giros son alrededor de los ejes de la cámara: X positivo sube lo que cuelga hacia delante de la articulación
-- (la boca del arma), Y positivo lo lleva a la izquierda.

export type Faction = "Guardians" | "Pirates"
export type Rig = {
	model: Model,
	root: BasePart,
	animator: Animator,
	controller: AnimationController,
}

-- Mangas de cada facción (la del laboratorio, bata blanca con puño azul; la pirata, negra con oro).
local SLEEVES: { [Faction]: { sleeve: Color3, cuff: Color3 } } = {
	Guardians = { sleeve = Color3.fromRGB(232, 236, 240), cuff = Color3.fromRGB(40, 115, 215) },
	Pirates = { sleeve = Color3.fromRGB(34, 31, 30), cuff = Color3.fromRGB(234, 194, 80) },
}

-- El arma mira hacia -Z con su lado de arriba hacia +Y (ejes de Shared/LabWeaponModels: +Y del mango hacia la
-- boca, -Z del mango hacia arriba).
local WEAPON_TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0))
-- El punto de la mano está a esto del centro del Handle, hacia la culata.
local GRIP_Y = 0.8

-- Hombro, codo y mano de cada brazo en el reposo (espacio de Root, studs). La mano derecha agarra la
-- empuñadura; la izquierda sujeta el arma delante, bajo el cajón. Los hombros quedan fuera de la pantalla.
local ARMS: { [string]: { shoulder: Vector3, elbow: Vector3, hand: Vector3 } } = {
	Right = {
		shoulder = Vector3.new(0.7, -1.7, 2.2),
		elbow = Vector3.new(0.1, -0.9, 1.0),
		hand = Vector3.new(0, -0.15, 0),
	},
	Left = {
		shoulder = Vector3.new(-0.6, -2.0, 1.7),
		elbow = Vector3.new(-0.2, -1.2, 0.2),
		hand = Vector3.new(0.05, -0.45, -1.1),
	},
}
local THICKNESS = 0.5
local HAND_SIZE = 0.45

local LabViewModelRig = {}

local function newPart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	return part
end

-- Bloque entre dos puntos, con su largo (Z) de uno a otro.
local function segment(name: string, from: Vector3, to: Vector3, color: Color3): Part
	local part = newPart(name, Vector3.new(THICKNESS, THICKNESS, (to - from).Magnitude), color)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	return part
end

-- Motor6D "name" entre dos piezas ya colocadas, con el pivote en "at" (espacio de Root). Cuelga de la pieza
-- hija, como en el R15.
local function joint(name: string, part0: BasePart, part1: BasePart, at: CFrame)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:ToObjectSpace(at)
	motor.C1 = part1.CFrame:ToObjectSpace(at)
	motor.Parent = part1
end

-- Un brazo (hombro, antebrazo, puño y mano). Devuelve la mano.
local function arm(model: Model, root: BasePart, side: string, colors: { sleeve: Color3, cuff: Color3 }, skin: Color3)
	local spec = ARMS[side]
	local upper = segment(`{side}UpperArm`, spec.shoulder, spec.elbow, colors.sleeve)
	local lower = segment(`{side}LowerArm`, spec.elbow, spec.hand, colors.sleeve)
	local direction = (spec.hand - spec.elbow).Unit
	local cuff = newPart(`{side}Cuff`, Vector3.new(THICKNESS + 0.05, THICKNESS + 0.05, 0.2), colors.cuff)
	cuff.CFrame = CFrame.lookAt(spec.hand - direction * 0.35, spec.hand)
	local cuffWeld = Instance.new("WeldConstraint")
	cuffWeld.Part0 = lower
	cuffWeld.Part1 = cuff
	cuffWeld.Parent = cuff
	local hand = newPart(`{side}Hand`, Vector3.one * HAND_SIZE, skin)
	hand.CFrame = CFrame.new(spec.hand)
	for _, part in { upper, lower, cuff, hand } do
		part.Parent = model
	end
	joint(`{side}Shoulder`, root, upper, CFrame.new(spec.shoulder))
	joint(`{side}Elbow`, upper, lower, CFrame.new(spec.elbow))
	joint(`{side}Hand`, lower, hand, CFrame.new(spec.hand))
	return hand
end

-- Monta el rig con "weaponModel" (el arma de la vista ya montada, con su "handle") y las manos de la facción.
-- Mueve las piezas del arma al rig y destruye "weaponModel". El modelo queda sin padre.
function LabViewModelRig.build(weaponModel: Model, handle: BasePart, faction: Faction, skin: Color3): Rig
	local model = Instance.new("Model")
	model.Name = "ArmaEnPrimeraPersona"
	local root = newPart("Root", Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1))
	root.Transparency = 1
	root.Anchored = true
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local colors = SLEEVES[faction]
	local rightHand = arm(model, root, "Right", colors, skin)
	arm(model, root, "Left", colors, skin)

	-- El arma: el punto de la mano (y = -GRIP_Y en el Handle) queda en el origen de Root.
	local target = WEAPON_TURN * CFrame.new(0, GRIP_Y, 0)
	local delta = target * handle.CFrame:Inverse()
	for _, part in weaponModel:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = delta * part.CFrame
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Massless = true
		end
	end
	for _, child in weaponModel:GetChildren() do
		child.Parent = model
	end
	weaponModel:Destroy()
	local grip = Instance.new("Motor6D")
	grip.Name = "WeaponGrip"
	grip.Part0 = rightHand
	grip.Part1 = handle
	grip.C0 = rightHand.CFrame:ToObjectSpace(CFrame.new())
	grip.C1 = handle.CFrame:ToObjectSpace(CFrame.new())
	grip.Parent = handle

	local controller = Instance.new("AnimationController")
	controller.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = controller
	return { model = model, root = root, animator = animator, controller = controller }
end

return LabViewModelRig
