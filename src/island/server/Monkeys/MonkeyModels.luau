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
-- Las especies en estilo voxel (VOXEL_SPECS: gorila, tití, mono ardilla, capuchino, aullador,
-- marimonda, marteja, cola larga, macaco, mandril, babuino, gibón, chimpancé y orangután) ya no
-- tienen constructor redondo: su cuerpo, sus pivotes y sus expresiones de la cara están en
-- VoxelSpecs/<Especie>.
-- Los simios (gorila, chimpancé, orangután, gibón) no tienen cola. Los jefes añaden sus detalles (BOSS_EXTRAS),
-- y algunas especies se construyen con más detalle cuando son un jefe (rig.boss).
-- Cada especie se construye una vez como plantilla y los monos son copias (MonkeyModels.spawn).
-- El Humanoid lo mueve como a un personaje.

local GeometryService = game:GetService("GeometryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)

-- Las posiciones de los constructores son respecto a la raíz, a escala 1, con la cara hacia -Z.
-- La raíz está a rootHeight sobre el suelo: con escala 1, el suelo queda en Y = -1.9.
-- "boss": lo construye un jefe; algunas especies le dan más detalle.
-- "voxel": el cuerpo es de bloques (voxelMonkey) y los adornos del jefe vienen en bloques en su spec.
-- "alpha": el líder de la tropa; más grande (scale ya lo incluye) y con su aspecto de macho dominante
-- ("alpha" en el spec voxel de su especie).
type Rig = { model: Model, root: BasePart, scale: number, boss: boolean, voxel: boolean, alpha: boolean }

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

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
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
-- Expresión de la cara: cajas que se unen en una pieza soldada a la cabeza. La "Normal" es la de
-- siempre; las demás se ven mientras suena una de sus "actions" (ver showFace y MonkeyAnimator).
type VoxelFace = { name: string, actions: { string }?, boxes: { { any } } }
-- El alfa de la tropa, con el dimorfismo de los machos dominantes (la capa plateada del babuino, el
-- lomo plateado del gorila): "tones", "remove" y "add" son como los de un jefe, "recolor" cambia
-- colores fijos del spec ({ de, a }) en el cuerpo y las caras, y "faces" cambia las cajas de las
-- expresiones de la especie por su nombre (la Normal, algo más agresiva).
type VoxelAlpha = {
	tones: { [string]: Color3 }?,
	recolor: { { Color3 } }?,
	remove: { string }?,
	add: { [string]: { { any } } }?,
	faces: { [string]: { { any } } }?,
}
-- "glowEyes": las cajas "Eye" (sueltas, de VOXEL_LOOSE) son de neón, como los ojos de la marteja.
-- "faces": expresiones según la acción (el grito del aullador al llamar a la tropa).
export type VoxelSpec = {
	unit: number,
	parts: { VoxelPart },
	bosses: { [string]: VoxelBoss }?,
	alpha: VoxelAlpha?,
	glowEyes: boolean?,
	faces: { VoxelFace }?,
}

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
		shade = darker(fur, 0.12), -- vetas de pelo más oscuras (orangután)
		deep = darker(skin, 0.25), -- almohadillas de las mejillas (orangután)
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

-- Muestra la expresión de la cara (atributo "Face", ver spec.faces) de una de las acciones que suenan
-- ("actions"); si ninguna tiene expresión propia, la "Normal". Devuelve si el modelo tiene expresiones.
local function showFace(model: Model, actions: { string }): boolean
	local faces: { BasePart } = {}
	local wanted = "Normal"
	for _, part in model:GetChildren() do
		local face = part:GetAttribute("Face")
		if part:IsA("BasePart") and typeof(face) == "string" then
			table.insert(faces, part)
			local faceActions = string.split(tostring(part:GetAttribute("FaceActions") or ""), " ")
			for _, action in actions do
				if table.find(faceActions, action) then
					wanted = face
				end
			end
		end
	end
	for _, part in faces do
		part.Transparency = if part:GetAttribute("Face") == wanted then 0 else 1
	end
	return #faces > 0
end

local function voxelMonkey(rig: Rig, definition: Monkeys.MonkeyDefinition, spec: VoxelSpec, bossId: string?)
	local tones = voxelTones(definition)
	local alpha: VoxelAlpha = if rig.alpha and spec.alpha then spec.alpha else {}
	local recolor = alpha.recolor or {}
	local function toneOf(value: any): Color3?
		local color = if typeof(value) == "Color3" then value elseif value then tones[value] else nil
		for _, pair in recolor do
			if color == pair[1] then
				return pair[2]
			end
		end
		return color
	end
	local unit = spec.unit
	local function at(x: number, y: number, z: number): Vector3
		return Vector3.new(x * unit, y * unit + GROUND, z * unit)
	end
	-- El alfa cambia el cuerpo como un jefe (tonos, cajas que quita y que añade), sin adornos.
	local boss: VoxelBoss = if bossId and spec.bosses
		then spec.bosses[bossId] or {}
		elseif rig.alpha then { tones = alpha.tones, remove = alpha.remove, add = alpha.add }
		else {}
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
					local glows = spec.glowEyes and name == "Eye"
					local block = piece(rig, name, "Block", size, color, if glows then Enum.Material.Neon else nil)
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

	-- Cada grupo (adorno de un jefe o expresión de la cara), unido en una pieza de su material y
	-- soldado a su parte. Devuelve las piezas (dos si va a los dos lados).
	local function buildGroup(extra: VoxelExtra): { BasePart }
		local material = (Enum.Material :: any)[extra.material or "SmoothPlastic"] :: Enum.Material
		local groupColor = extra.color or tones[extra.tone or "fur"]
		local groups: { BasePart } = {}
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
			table.insert(groups, group)
		end
		return groups
	end

	-- Expresiones de la cara: solo se ve la "Normal" hasta que una acción pide otra (showFace). Los
	-- jefes con entrada en el spec ponen su propia cara por fases y no llevan las de la especie.
	local bossFaces = bossId ~= nil and spec.bosses ~= nil and spec.bosses[bossId] ~= nil
	for _, face in if bossFaces then {} else spec.faces or {} do
		local boxes = if alpha.faces and alpha.faces[face.name] then alpha.faces[face.name] else face.boxes
		for _, group in buildGroup({ anchor = "Head", name = "Expression", boxes = boxes }) do
			group:SetAttribute("Face", face.name)
			group:SetAttribute("FaceActions", table.concat(face.actions or {}, " "))
		end
	end
	showFace(rig.model, {})

	-- Adornos del jefe.
	for _, extra in boss.groups or {} do
		for _, group in buildGroup(extra) do
			if extra.phase then
				group:SetAttribute("Phase", extra.phase)
				group:SetAttribute("BaseTransparency", group.Transparency)
			end
		end
	end
	showPhase(rig.model, 1)
end
MonkeyModels.showPhase = showPhase
MonkeyModels.showFace = showFace

-- Especies con modelo voxel en el juego.
local VOXEL_SPECS: { [string]: VoxelSpec } = {
	Gorila = require(script.Parent.VoxelSpecs.Gorila) :: any,
	Titi = require(script.Parent.VoxelSpecs.Titi) :: any,
	MonoArdilla = require(script.Parent.VoxelSpecs.MonoArdilla) :: any,
	CapuchinoLadron = require(script.Parent.VoxelSpecs.CapuchinoLadron) :: any,
	AulladorRojo = require(script.Parent.VoxelSpecs.AulladorRojo) :: any,
	Marimonda = require(script.Parent.VoxelSpecs.Marimonda) :: any,
	Marteja = require(script.Parent.VoxelSpecs.Marteja) :: any,
	ColaLarga = require(script.Parent.VoxelSpecs.ColaLarga) :: any,
	Macaco = require(script.Parent.VoxelSpecs.Macaco) :: any,
	Mandril = require(script.Parent.VoxelSpecs.Mandril) :: any,
	Babuino = require(script.Parent.VoxelSpecs.Babuino) :: any,
	Gibon = require(script.Parent.VoxelSpecs.Gibon) :: any,
	Chimpance = require(script.Parent.VoxelSpecs.Chimpance) :: any,
	Orangutan = require(script.Parent.VoxelSpecs.Orangutan) :: any,
}
-- Jefes que ya usan el cuerpo voxel de su especie, con sus adornos en bloques. Los demás siguen con
-- el modelo de antes hasta que tengan sus detalles. La vista previa los activa en su copia del módulo
-- (MM.voxelBosses.GorilaAlbino = true) para probarlos. Si su especie ya no tiene constructor redondo
-- (como el gorila), el jefe tiene que estar aquí o saldría con el cuerpo del mono genérico.
local VOXEL_BOSSES: { [string]: boolean } = {
	GorilaAlbino = true,
	GorilaDeCeniza = true,
	ChimpanceCaudillo = true,
	OrangutanDelManglar = true,
}
MonkeyModels.voxelSpecs = VOXEL_SPECS
MonkeyModels.voxelBosses = VOXEL_BOSSES

local BUILDERS: { [string]: (rig: Rig, definition: Monkeys.MonkeyDefinition) -> () } = {}

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

-- Escala con la que se construye un mono: la de su especie, y más si es el alfa de la tropa.
function MonkeyModels.scaleOf(definition: Monkeys.MonkeyDefinition, alpha: boolean?): number
	return definition.scale * (if alpha then Config.Monkeys.AlphaScale else 1)
end

-- Construye un mono nuevo. "ground" es el punto del suelo donde aparece. Los jefes lo usan con su
-- propio aspecto y su id ("bossId", para sus detalles); los monos normales salen de MonkeyModels.spawn.
-- "alpha": el líder de la tropa (especies con "alpha" en Data/Monkeys), más grande y de colores más marcados.
function MonkeyModels.build(
	speciesId: string,
	definition: Monkeys.MonkeyDefinition,
	ground: Vector3,
	bossId: string?,
	alpha: boolean?
): Model
	local isAlpha = alpha == true and bossId == nil
	local s = MonkeyModels.scaleOf(definition, isAlpha)
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
	local rig: Rig =
		{ model = model, root = root, scale = s, boss = bossId ~= nil, voxel = voxelSpec ~= nil, alpha = isAlpha }
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
-- El alfa tiene su propia plantilla: sus colores van dentro de las uniones y no se pueden cambiar después.
function MonkeyModels.spawn(
	speciesId: string,
	definition: Monkeys.MonkeyDefinition,
	ground: Vector3,
	alpha: boolean?
): Model
	local key = if alpha then `{speciesId}Alpha` else speciesId
	local template = templates[key]
	if not template then
		template = MonkeyModels.build(speciesId, definition, Vector3.zero, nil, alpha)
		templates[key] = template
	end
	local model = template:Clone()
	local height = MonkeyModels.rootHeight(MonkeyModels.scaleOf(definition, alpha))
	model:PivotTo(CFrame.new(ground + Vector3.new(0, height, 0)))
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
