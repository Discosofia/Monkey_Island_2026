--!strict
-- Modelos de las mascotas (Fase 5): una figura de piezas simples por especie, con partes animadas
-- (alas que baten, patas que andan, colas que se mueven). Los crean los clientes (Lobby e Isla) para
-- que sigan a su dueño (UI/PetFollowers); el servidor no los conoce.
-- Skins (Fase 9, G9c; Data/Cosmetics, tipo PetSkin): cambian los colores que su constructor lee con
-- "tone", el material de esos colores y añaden piezas propias (SKINS, al final del archivo).
--   Skin    atributo del modelo con la skin que lleva
-- Se construyen alrededor de una pieza invisible "Root" (el pivote), con -Z hacia delante.
-- Atributos del modelo:
--   Motion  "Walk" (por el suelo), "Hop" (a saltos), "Fly" (vuela alto) o "Hover" (flota cerca)
--   Height  altura del pivote sobre la parte más baja, para apoyarlo en el suelo

local CosmeticSlots = require(script.Parent.CosmeticSlots)
local Cosmetics = require(script.Parent.Data.Cosmetics)
local PetMeshes = require(script.Parent.Data.PetMeshes)
local Pets = require(script.Parent.Data.Pets)

local AssetService = game:GetService("AssetService")

export type Motion = "Walk" | "Hop" | "Fly" | "Hover"

-- "Spike": pirámide (CornerWedgePart) con la punta sobre la esquina -X +Z de arriba; sirve para cristales.
type Shape = "Ball" | "Oval" | "Block" | "Cylinder" | "Wedge" | "Spike"

type Joint = {
	part: BasePart,
	hinge: CFrame,
	offset: CFrame,
	axis: Vector3,
	amplitude: number,
	speed: number,
	phase: number,
	gait: boolean, -- solo se mueve mientras el dueño anda
	bias: number, -- se suma al seno: con bias = amplitude, el giro va de 0 a 2 * amplitude (nunca al revés)
	parent: Joint?, -- articulación encadenada (rodilla, codo): primero gira con la de arriba
	bone: string?, -- nombre con el que la mueven los clips (ver CLIPS): "Head", "Tail", "FL", "WingL"…
	lag: number, -- puesto en una cadena (la cola): las ondas de los clips le llegan con este retraso
	world: CFrame, -- giro de este fotograma respecto al pivote (lo usan las que cuelgan de ella)
	bend: number, -- cuánto gira en Y con el giro de la mascota ("bend" de animate): la cadera y la cabeza
}

-- Clips: posturas con fotogramas clave que se suman a los senos de las articulaciones (sentarse,
-- tumbarse, el ataque de cada mascota). Cada fotograma da, en grados, el giro de cada hueso sobre su
-- bisagra ({ x, y, z }, con CFrame.fromEulerAnglesYXZ); "Body" mueve la mascota entera alrededor de "around"
-- ({ x, y, z, px, py, pz }, desplazamiento en studs sin escalar). Un hueso que no aparece en un
-- fotograma está en reposo en él. Además:
--   gait   cuánto andan las patas (0 a 1) en vez de lo que anda el dueño (andar alrededor de él)
--   amp    { [hueso] = factor } de su seno de siempre (0 = quieto: las patas mientras salta)
--   waves  { [hueso] = { x?, y?, z?, px?, py?, pz?, speed = rad/s, phase = rad, lag = rad } }: ondas
--          que se suman a la pose (lamerse, la cola que barre el suelo); en una cadena, cada tramo
--          la recibe "lag" radianes más tarde, y la cola ondula
--   linear el tramo que sale de este fotograma va a velocidad constante (por defecto, suave)
type Key = { [string]: any }
export type Clip = { length: number, loop: boolean?, around: Vector3?, keys: { Key } }
-- Un clip sonando: su nombre, su tiempo y su peso (0 a 1, para entrar y salir sin saltos).
export type Layer = { clip: string, time: number, weight: number }

type Rig = {
	model: Model,
	scale: number,
	joints: { Joint },
	family: string?, -- familia de clips (CLIPS)
	dims: { [string]: any }?, -- medidas que necesitan sus clips
	palette: { [string]: Color3 }?, -- colores de la skin puesta (SKINS), que lee "tone"
	-- Piezas fijas de la cadera (manchas, vientre) que giran sobre la cintura ("hinge", sin escalar) con
	-- el giro de la mascota, "factor" veces. No son articulaciones: solo se mueven mientras gira.
	bend: { hinge: CFrame, factor: number, parts: { BasePart } }?,
}
type Animated = {
	joints: { Joint },
	statics: { BasePart },
	rest: { CFrame }, -- de cada pieza fija, respecto al pivote
	clips: { [string]: Clip },
	scale: number,
	bodyMoved: boolean,
	bend: { hinge: CFrame, factor: number, parts: { BasePart }, rest: { CFrame } }?,
	bendMoved: boolean,
}

local WHITE = Color3.fromRGB(245, 245, 238)
local BLACK = Color3.fromRGB(22, 22, 26)

local rigs: { [Model]: Animated } = {}

local PetModels = {}

-- Color "key" de la mascota: el de su skin si la lleva y lo cambia (SKINS), si no "default".
local function tone(rig: Rig, key: string, default: Color3): Color3
	local palette = rig.palette
	return if palette and palette[key] then palette[key] else default
end

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
	elseif shape == "Spike" then
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

-- Hace que una pieza gire alrededor de una bisagra (en coordenadas del modelo, sin escalar). El giro
-- es sin(t * speed + phase) * amplitude (+ bias, opcional, para que solo vaya hacia un lado). Con
-- "parent" (otra articulación ya creada) la bisagra se mueve con ella: así la rodilla sigue al muslo.
local function joint(
	rig: Rig,
	part: BasePart,
	hinge: CFrame,
	axis: Vector3,
	amplitude: number,
	speed: number,
	phase: number,
	gait: boolean,
	bias: number?,
	parent: Joint?
): Joint
	local hingeFrame = scaled(rig, hinge)
	local item: Joint = {
		part = part,
		hinge = hingeFrame,
		offset = hingeFrame:Inverse() * part.CFrame,
		axis = axis,
		amplitude = amplitude,
		speed = speed,
		phase = phase,
		gait = gait,
		bias = bias or 0,
		parent = parent,
		lag = 0,
		world = CFrame.identity,
		bend = 0,
	}
	table.insert(rig.joints, item)
	return item
end

-- Pega "part" a la pieza articulada "base": se mueve con ella como si fueran una sola (lo que una skin
-- añade a la cola o a la cabeza). Devuelve si "base" tenía articulación.
local function attachTo(rig: Rig, part: BasePart, base: BasePart): boolean
	for _, item in rig.joints do
		if item.part == base then
			local copy = table.clone(item)
			copy.part = part
			copy.offset = item.hinge:Inverse() * part.CFrame
			table.insert(rig.joints, copy)
			return true
		end
	end
	return false
end

-- Articula sobre "hinge" todas las piezas ya creadas cuyo centro (sin escalar) cumple "inside" y que
-- no se mueven ya por su cuenta: la cabeza entera con sus ojos, bigotes y orejas, o la cola con sus
-- plumas. Llamar al final del constructor, cuando ya están todas las piezas. Devuelve sus
-- articulaciones (para darles un hueso).
local function swingRegion(
	rig: Rig,
	hinge: Vector3,
	axis: Vector3,
	amplitude: number,
	speed: number,
	phase: number,
	gait: boolean,
	inside: (position: Vector3) -> boolean,
	bone: string?
): { Joint }
	local moving: { [BasePart]: boolean } = {}
	for _, item in rig.joints do
		moving[item.part] = true
	end
	local added: { Joint } = {}
	for _, part in rig.model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Root" and not moving[part] and inside(part.Position / rig.scale) then
			local item = joint(rig, part, CFrame.new(hinge), axis, amplitude, speed, phase, gait)
			item.bone = bone
			table.insert(added, item)
		end
	end
	return added
end

-- Óvalo alargado entre dos puntos (brazos, muslos): sus extremos redondos tapan las juntas. De
-- pelo (Fabric) salvo que se pida otro material.
local function capsule(
	rig: Rig,
	name: string,
	from: Vector3,
	to: Vector3,
	width: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	local length = (to - from).Magnitude + width * 0.5
	return piece(
		rig,
		name,
		"Oval",
		Vector3.new(width, width, length),
		CFrame.lookAt((from + to) / 2, to),
		color,
		material or Enum.Material.Fabric
	)
end

-- Pieza plana pegada a una superficie, mirando hacia "normal" (manchas, placas, parches).
local function patch(rig: Rig, name: string, size: Vector3, position: Vector3, normal: Vector3, color: Color3): BasePart
	return piece(rig, name, "Oval", size, CFrame.lookAt(position, position + normal.Unit), color)
end

-- Punto de la superficie de un óvalo (centro y giro "frame", semiejes "semi") en la dirección
-- "direction" (en ejes del óvalo), y su normal en ejes del modelo. Sirve para pegar placas, manchas
-- y escamas a un cuerpo redondo sin que floten ni se hundan.
local function surfacePoint(frame: CFrame, semi: Vector3, direction: Vector3): (Vector3, Vector3)
	local d = direction.Unit
	local point = d / math.sqrt((d.X / semi.X) ^ 2 + (d.Y / semi.Y) ^ 2 + (d.Z / semi.Z) ^ 2)
	local normal = Vector3.new(point.X / semi.X ^ 2, point.Y / semi.Y ^ 2, point.Z / semi.Z ^ 2).Unit
	return frame * point, frame:VectorToWorldSpace(normal)
end

-- Cola larga por tramos sobre una curva (de "base" a "to", tirando hacia "control") que ondula de
-- lado a lado: cada tramo gira sobre el final del anterior (hueso "Tail", encadenado), así que los
-- clips la enroscan girando todos los tramos lo mismo. Opcional: anillos de otro color ("bands") y
-- punta ("tip").
local function tail(
	rig: Rig,
	color: Color3,
	base: Vector3,
	control: Vector3,
	to: Vector3,
	width: number,
	wag: number,
	tip: Color3?,
	bands: Color3?,
	material: Enum.Material?
)
	local segments = 5
	local function at(t: number): Vector3
		return base:Lerp(control, t):Lerp(control:Lerp(to, t), t)
	end
	-- Piezas de cada tramo (los anillos y la punta van con el tramo en el que caen).
	local parts: { { BasePart } } = {}
	for i = 1, segments do
		local from, next = at((i - 1) / segments), at(i / segments)
		local thickness = width * (1 - (i - 1) * 0.08)
		parts[i] = { capsule(rig, "Tail", from, next, thickness, color, material) }
	end
	local function segmentOf(t: number): { BasePart }
		return parts[math.clamp(math.floor(t * segments) + 1, 1, segments)]
	end
	if bands then
		for _, t in { 0.55, 0.72, 0.88 } do
			local from, next = at(t - 0.025), at(t + 0.025)
			table.insert(segmentOf(t), capsule(rig, "TailBand", from, next, width * (1.08 - t * 0.4), bands, material))
		end
	end
	if tip then
		table.insert(parts[segments], capsule(rig, "TailTip", at(0.94), to, width * 0.72, tip, material))
	end
	local previous: Joint? = nil
	for i = 1, segments do
		local hinge = CFrame.new(at((i - 1) / segments))
		local last: Joint? = nil
		for _, part in parts[i] do
			-- Cada tramo mueve una parte del meneo y un poco más tarde que el anterior: ondula.
			local item = joint(rig, part, hinge, Vector3.yAxis, wag * 0.3, 5, -(i - 1) * 0.55, false, nil, previous)
			item.bone = "Tail"
			item.lag = i - 1
			last = item
		end
		previous = last
	end
end

type CatOptions = {
	eyeColor: Color3,
	earSize: number,
	spots: Color3?, -- rosetas y rayas (ocelote) o manchas que brillan (cristal)
	crystal: boolean?,
	roundEars: boolean?,
	slim: boolean?, -- cuerpo largo y bajo, cabeza pequeña y cola larga (jaguarundí)
}

-- Felino: cuerpo con hombros y ancas marcados, cabeza con mofletes, hocico de dos almohadillas, nariz,
-- ojos almendrados con la pupila en rendija, orejas con interior, patas con dedos y cola por tramos.
local function cat(rig: Rig, coat: Color3, options: CatOptions)
	local crystal = options.crystal == true
	-- El de cristal es de hielo facetado (Glacier): con vidrio liso parecía un globo y se veían
	-- por dentro todas las piezas solapadas.
	local fur = if crystal then Enum.Material.Glacier else Enum.Material.Fabric
	local light = coat:Lerp(WHITE, 0.45)
	local dark = coat:Lerp(BLACK, 0.45)
	local slim = options.slim == true
	local length = if slim then 2.4 else 2.1
	local legHeight = if slim then 0.62 else 0.75
	local headSize = if slim then 0.72 else 0.85
	local bodyY = if slim then -0.08 else 0
	local bodySemi = Vector3.new(0.475, 0.425, length / 2)
	local bodyFrame = CFrame.new(0, bodyY, 0)
	piece(rig, "Body", "Oval", bodySemi * 2, bodyFrame, coat, fur)
	piece(rig, "Chest", "Oval", Vector3.new(0.82, 0.82, 0.9), CFrame.new(0, bodyY + 0.05, -length * 0.36), coat, fur)
	piece(rig, "Belly", "Oval", Vector3.new(0.62, 0.4, length * 0.62), CFrame.new(0, bodyY - 0.24, -0.1), light, fur)
	for _, side in { -1, 1 } do
		-- Paletillas, ancas y pecho: le dan músculo y quitan el aspecto de salchicha.
		piece(
			rig,
			"ShoulderBlade",
			"Oval",
			Vector3.new(0.36, 0.66, 0.55),
			CFrame.new(side * 0.3, bodyY + 0.12, -length * 0.3) * CFrame.Angles(0.25, 0, 0),
			coat,
			fur
		)
		piece(
			rig,
			"Haunch",
			"Oval",
			Vector3.new(0.46, 0.8, 0.8),
			CFrame.new(side * 0.27, bodyY + 0.04, length * 0.3),
			coat,
			fur
		)
		piece(
			rig,
			"Pectoral",
			"Oval",
			Vector3.new(0.32, 0.42, 0.32),
			CFrame.new(side * 0.16, bodyY - 0.14, -length * 0.42),
			coat,
			fur
		)
	end

	-- Cabeza.
	local head = Vector3.new(0, 0.5, -length / 2 - 0.2)
	local radius = headSize / 2
	local neckTo = head + Vector3.new(0, -0.15, 0.25)
	capsule(rig, "Neck", Vector3.new(0, bodyY + 0.2, -length * 0.38), neckTo, 0.66 * headSize / 0.85, coat, fur)
	piece(rig, "Head", "Ball", Vector3.one * headSize, CFrame.new(head), coat, fur)
	local muzzleY = head.Y - radius * 0.3
	local front = head.Z - radius
	for _, side in { -1, 1 } do
		piece(
			rig,
			"Cheek",
			"Oval",
			Vector3.new(0.34, 0.4, 0.36) * headSize / 0.85,
			CFrame.new(head + Vector3.new(side * radius * 0.7, -radius * 0.3, -radius * 0.15)),
			coat,
			fur
		)
		piece(
			rig,
			"WhiskerPad",
			"Oval",
			Vector3.new(0.24, 0.2, 0.22) * headSize / 0.85,
			CFrame.new(side * radius * 0.24, muzzleY, front - 0.02),
			light,
			fur
		)
	end
	piece(
		rig,
		"Chin",
		"Oval",
		Vector3.new(0.2, 0.13, 0.18) * headSize / 0.85,
		CFrame.new(0, muzzleY - radius * 0.25, front + 0.04),
		light,
		fur
	)
	piece(
		rig,
		"Bridge",
		"Oval",
		Vector3.new(0.18, 0.18, 0.4) * headSize / 0.85,
		CFrame.new(0, head.Y - radius * 0.02, front + 0.08),
		coat,
		fur
	)
	local noseColor = if crystal then options.spots or coat else Color3.fromRGB(170, 95, 95)
	piece(
		rig,
		"Nose",
		"Oval",
		Vector3.new(0.15, 0.09, 0.08) * headSize / 0.85,
		CFrame.new(0, muzzleY + radius * 0.2, front - 0.1),
		noseColor
	)
	piece(
		rig,
		"Philtrum",
		"Block",
		Vector3.new(0.02, 0.07, 0.02),
		CFrame.new(0, muzzleY + radius * 0.05, front - 0.115),
		dark
	)
	for _, side in { -1, 1 } do
		piece(
			rig,
			"Mouth",
			"Oval",
			Vector3.new(0.11, 0.022, 0.03),
			CFrame.new(side * 0.05, muzzleY - radius * 0.04, front - 0.11) * CFrame.Angles(0, 0, side * 0.35),
			dark
		)
		-- Bigotes: tres por lado, abiertos en abanico y hacia atrás.
		for k = -1, 1 do
			piece(
				rig,
				"Whisker",
				"Block",
				Vector3.new(0.5, 0.022, 0.022),
				CFrame.new(side * (radius * 0.24 + 0.22), muzzleY + k * 0.04, front + 0.02)
					* CFrame.Angles(0, -side * 0.35, side * k * 0.2),
				Color3.fromRGB(240, 240, 230)
			)
		end
	end

	-- Ojos almendrados: contorno oscuro, iris y pupila en rendija, sobre la superficie de la cabeza.
	for _, side in { -1, 1 } do
		local normal = Vector3.new(side * 0.45, 0.3, -0.84).Unit
		local position = head + normal * (radius - 0.01)
		local frame = CFrame.lookAt(position, position + normal) * CFrame.Angles(0, 0, side * 0.22)
		local s = headSize / 0.85
		piece(rig, "EyeLine", "Oval", Vector3.new(0.24, 0.16, 0.08) * s, frame, BLACK)
		piece(
			rig,
			"Eye",
			"Oval",
			Vector3.new(0.2, 0.13, 0.08) * s,
			frame * CFrame.new(0, 0, -0.01),
			options.eyeColor,
			if crystal then Enum.Material.Neon else nil
		)
		piece(
			rig,
			"Pupil",
			"Oval",
			Vector3.new(0.035, 0.12, 0.08) * s,
			frame * CFrame.new(0, 0, -0.018),
			if crystal then Color3.fromRGB(20, 60, 120) else BLACK
		)
		piece(
			rig,
			"Glint",
			"Ball",
			Vector3.one * 0.04 * s,
			frame * CFrame.new(-side * 0.03, 0.025, -0.05),
			WHITE,
			Enum.Material.Neon
		)
		-- Lagrimal claro debajo del ojo, como los felinos de verdad.
		piece(
			rig,
			"EyeMark",
			"Oval",
			Vector3.new(0.12, 0.05, 0.06) * s,
			frame * CFrame.new(side * 0.02, -0.09 * s, 0.005),
			light
		)
	end

	-- Orejas: triangulares (o redondas y pequeñas) con el interior rosado y un mechón claro.
	local innerEar = if crystal then options.spots or coat else Color3.fromRGB(225, 150, 150)
	local earSize = options.earSize
	for _, side in { -1, 1 } do
		local ear = CFrame.new(side * radius * 0.6, head.Y + radius * 0.85 + earSize * 0.25, head.Z + 0.05)
			* CFrame.Angles(0, 0, -side * 0.25)
		if options.roundEars then
			piece(rig, "Ear", "Oval", Vector3.new(earSize, earSize * 0.85, 0.12), ear, coat, fur)
			piece(
				rig,
				"InnerEar",
				"Oval",
				Vector3.new(earSize * 0.6, earSize * 0.5, 0.08),
				ear * CFrame.new(0, -0.02, -0.03),
				innerEar
			)
		else
			piece(rig, "Ear", "Wedge", Vector3.new(0.12, earSize, 0.28), ear, coat, fur)
			piece(
				rig,
				"InnerEar",
				"Wedge",
				Vector3.new(0.07, earSize * 0.7, 0.18),
				ear * CFrame.new(0, -earSize * 0.12, -0.05),
				innerEar
			)
			piece(
				rig,
				"EarTuft",
				"Oval",
				Vector3.new(0.05, earSize * 0.4, 0.05),
				ear * CFrame.new(0, -earSize * 0.15, -0.09),
				light,
				fur
			)
		end
	end

	-- Patas de dos tramos con músculo: brazo y antebrazo delante (codo), muslo, espinilla y caña
	-- detrás (rodilla y corvejón). El tramo de abajo cuelga del de arriba (joint con parent) y se dobla
	-- hacia atrás mientras la pata avanza en el aire, como al andar de verdad.
	local paw = coat:Lerp(light, 0.5)
	local muscle = coat:Lerp(BLACK, 0.08)
	local legY = bodyY - 0.6 + (0.75 - legHeight) / 2
	local ground = legY - 0.56 * legHeight
	local top = bodyY - 0.1
	local span = top - ground
	local phases = { 0, math.pi, math.pi, 0 }
	-- Huesos de los clips: F/B delante o detrás, L/R izquierda (-X) o derecha; con "2", el tramo de abajo.
	local bones = { "FL", "FR", "BL", "BR" }
	for i, spot in { { -1, true }, { 1, true }, { -1, false }, { 1, false } } do
		local side: number, isFront: boolean = spot[1], spot[2]
		local x = side * 0.29
		local z = (if isFront then -1 else 1) * length * 0.31
		local hip = if isFront then Vector3.new(x, top, z) else Vector3.new(x * 0.95, top + 0.05, z)
		-- Codo un poco hacia atrás; rodilla hacia delante.
		local knee = if isFront
			then Vector3.new(x * 1.03, top - span * 0.45, z + 0.07)
			else Vector3.new(x * 1.05, top - span * 0.42, z - 0.12)
		local ankle = if isFront
			then Vector3.new(x, ground + span * 0.14, z - 0.02)
			else Vector3.new(x, ground + 0.08, z + 0.02)
		local upper: { BasePart } = {}
		local lower: { BasePart } = {}
		if isFront then
			table.insert(upper, capsule(rig, "UpperArm", hip, knee, 0.36, coat, fur))
			table.insert(
				upper,
				piece(
					rig,
					"Triceps",
					"Oval",
					Vector3.new(0.3, span * 0.42, 0.3),
					CFrame.new(hip:Lerp(knee, 0.55) + Vector3.new(side * 0.02, 0, 0.08)),
					muscle,
					fur
				)
			)
			table.insert(lower, capsule(rig, "Forearm", knee, ankle, 0.24, coat, fur))
			table.insert(
				lower,
				piece(
					rig,
					"ForearmMuscle",
					"Oval",
					Vector3.new(0.26, span * 0.24, 0.26),
					CFrame.new(knee:Lerp(ankle, 0.28) + Vector3.new(0, 0, -0.03)),
					coat,
					fur
				)
			)
		else
			-- Corvejón: el codo de la pata de atrás, que apunta hacia atrás.
			local hock = Vector3.new(x * 1.03, ground + span * 0.3, z + 0.14)
			table.insert(upper, capsule(rig, "Thigh", hip, knee, 0.44, coat, fur))
			table.insert(
				upper,
				piece(
					rig,
					"ThighMuscle",
					"Oval",
					Vector3.new(0.38, span * 0.56, 0.5),
					CFrame.new(hip:Lerp(knee, 0.4) + Vector3.new(0, 0, 0.08)),
					muscle,
					fur
				)
			)
			table.insert(lower, capsule(rig, "Shin", knee, hock, 0.25, coat, fur))
			table.insert(
				lower,
				piece(
					rig,
					"Calf",
					"Oval",
					Vector3.new(0.22, span * 0.26, 0.24),
					CFrame.new(knee:Lerp(hock, 0.4) + Vector3.new(0, 0, 0.06)),
					muscle,
					fur
				)
			)
			table.insert(lower, capsule(rig, "Cannon", hock, ankle, 0.18, coat, fur))
		end
		local pawCenter = Vector3.new(x, ground + 0.065, ankle.Z - 0.08)
		table.insert(lower, piece(rig, "Paw", "Oval", Vector3.new(0.34, 0.14, 0.4), CFrame.new(pawCenter), paw, fur))
		for k = -1, 1 do
			local toe = pawCenter + Vector3.new(k * 0.095, -0.005, -0.18 + math.abs(k) * 0.03)
			table.insert(lower, piece(rig, "Toe", "Ball", Vector3.one * 0.11, CFrame.new(toe), paw, fur))
		end
		local thigh: Joint? = nil
		for _, part in upper do
			thigh = joint(rig, part, CFrame.new(hip), Vector3.xAxis, 0.45, 9, phases[i], true)
			thigh.bone = bones[i]
		end
		for _, part in lower do
			local item =
				joint(rig, part, CFrame.new(knee), Vector3.xAxis, -0.3, 9, phases[i] + math.pi / 2, true, -0.3, thigh)
			item.bone = bones[i] .. "2"
		end
	end
	local tailBase = Vector3.new(0, bodyY + 0.2, length / 2 - 0.1)
	local tailLength = if slim then 1.9 else 1.5
	tail(
		rig,
		coat,
		tailBase,
		tailBase + Vector3.new(0, 0.55, tailLength * 0.45),
		tailBase + Vector3.new(0, 0.35, tailLength),
		0.22,
		0.5,
		if options.spots then options.spots else dark,
		if options.spots and not crystal then options.spots else nil,
		if crystal then fur else nil
	)

	if options.spots and not crystal then
		-- Ocelote: rosetas abiertas (contorno negro con el centro más tostado) en filas por los
		-- costados, rayas por el lomo y el cuello, y motas y rayas en la cabeza.
		local center = coat:Lerp(Color3.fromRGB(130, 75, 25), 0.55)
		-- Punto del costado de un óvalo a la altura "y" y la "z" pedidas (en el modelo).
		local function flank(frame: CFrame, semi: Vector3, side: number, y: number, z: number): (Vector3, Vector3)
			local point = frame:PointToObjectSpace(Vector3.new(0, y, z))
			local x = semi.X * math.sqrt(math.max(0.05, 1 - (point.Y / semi.Y) ^ 2 - (point.Z / semi.Z) ^ 2))
			return surfacePoint(frame, semi, Vector3.new(side * x, point.Y, point.Z))
		end
		local function rosette(position: Vector3, normal: Vector3, size: Vector2, spin: number)
			local frame = CFrame.lookAt(position, position + normal) * CFrame.Angles(0, 0, spin)
			piece(rig, "Rosette", "Oval", Vector3.new(size.X, size.Y, 0.05), frame, options.spots)
			piece(
				rig,
				"RosetteCenter",
				"Oval",
				Vector3.new(size.X * 0.74, size.Y * 0.6, 0.05),
				frame * CFrame.new(0, 0, -0.008),
				center
			)
		end
		for _, side in { -1, 1 } do
			-- Filas de rosetas alargadas por el costado (entre paletilla y anca), y unas pocas en el
			-- anca y la paletilla, que tapan el cuerpo por ahí.
			for row, y in { bodyY + 0.22, bodyY - 0.02, bodyY - 0.24 } do
				for k = -1, 1 do
					local position, normal = flank(bodyFrame, bodySemi, side, y, k * 0.3 + (row % 2) * 0.12 - 0.05)
					rosette(position, normal, Vector2.new(0.3, 0.16), k * 0.2 + row * 0.15)
				end
			end
			local haunch = CFrame.new(side * 0.27, bodyY + 0.04, length * 0.3)
			for k, offset in { Vector3.new(0, 0.18, -0.1), Vector3.new(0, -0.08, 0.12), Vector3.new(0, -0.05, -0.2) } do
				local position, normal =
					flank(haunch, Vector3.new(0.23, 0.4, 0.4), side, haunch.Y + offset.Y, haunch.Z + offset.Z)
				rosette(position, normal, Vector2.new(0.2, 0.13), k * 0.7)
			end
			local blade = CFrame.new(side * 0.3, bodyY + 0.12, -length * 0.3) * CFrame.Angles(0.25, 0, 0)
			for k, offset in { Vector3.new(0, 0.1, 0), Vector3.new(0, -0.14, 0.06) } do
				local position, normal =
					flank(blade, Vector3.new(0.18, 0.33, 0.275), side, blade.Y + offset.Y, blade.Z + offset.Z)
				rosette(position, normal, Vector2.new(0.16, 0.11), k * 0.9)
			end
			-- Rayas del cuello.
			for k = 0, 1 do
				local position, normal = flank(bodyFrame, bodySemi, side, bodyY + 0.3 - k * 0.22, -length * 0.38)
				patch(rig, "NeckStripe", Vector3.new(0.3, 0.06, 0.04), position, normal, options.spots)
			end
			-- Rayas negras de la mejilla, desde el ojo.
			local cheek = head + Vector3.new(side * radius * 0.75, -radius * 0.15, -radius * 0.55)
			patch(rig, "CheekStripe", Vector3.new(0.05, 0.2, 0.04), cheek, cheek - head, options.spots)
			-- Dorso de la oreja negro.
			local earBack = CFrame.new(side * radius * 0.6, head.Y + radius * 0.85 + earSize * 0.25, head.Z + 0.12)
				* CFrame.Angles(0, 0, -side * 0.25)
			piece(rig, "EarBack", "Oval", Vector3.new(0.1, earSize * 0.6, 0.04), earBack, options.spots)
		end
		-- Rayas a trozos por el lomo: un trozo recto largo se despega del lomo curvo.
		for _, x in { -0.08, 0.08 } do
			for k = 0, 3 do
				local z = -0.6 + k * 0.4
				local y = bodySemi.Y * math.sqrt(1 - (z / bodySemi.Z) ^ 2 - (x / bodySemi.X) ^ 2)
				local position, normal = surfacePoint(bodyFrame, bodySemi, Vector3.new(x, y, z))
				piece(
					rig,
					"BackStripe",
					"Oval",
					Vector3.new(0.06, 0.04, 0.24),
					CFrame.lookAt(position, position + Vector3.zAxis, normal),
					options.spots
				)
			end
		end
		for _, offset in
			{
				Vector3.new(0.1, 0.36, -0.22),
				Vector3.new(-0.1, 0.36, -0.22),
			}
		do
			local position = head + offset.Unit * radius
			patch(rig, "HeadSpot", Vector3.new(0.05, 0.08, 0.03), position, offset, options.spots)
		end
	elseif options.spots then
		-- Cristal: manchas que brillan bajo la piel de vidrio.
		for _, side in { -1, 1 } do
			for row, y in { 0.4, -0.1 } do
				for k = 0, 2 do
					local position, normal =
						surfacePoint(bodyFrame, bodySemi, Vector3.new(side, y, -0.45 + k * 0.45 + row * 0.15))
					patch(rig, "Spot", Vector3.new(0.22, 0.15, 0.05), position, normal, options.spots).Material =
						Enum.Material.Neon
				end
			end
		end
	end

	if crystal then
		for _, part in rig.model:GetChildren() do
			if part:IsA("BasePart") and part.Material == fur then
				part.Transparency = 0.15
			end
		end
	end
	-- La cabeza (con cuello, orejas, bigotes y ojos) mira despacio a un lado y a otro.
	local neckZ = -length / 2 + 0.15
	swingRegion(rig, Vector3.new(0, 0.4, neckZ), Vector3.yAxis, 0.25, 0.9, 0, false, function(position)
		return position.Z < neckZ - 0.05 and position.Y > bodyY + 0.12
	end, "Head")
	rig.family = "Cat"
	rig.dims = {
		length = length,
		legHeight = legHeight,
		bodyY = bodyY,
		ground = ground,
		-- Cadera de atrás y hombros (el centro, entre las dos patas), y centro del cuerpo.
		hips = Vector3.new(0, top + 0.05, length * 0.31),
		shoulders = Vector3.new(0, top, -length * 0.31),
		center = Vector3.new(0, bodyY, 0),
		-- Lo más bajo de las ancas en reposo: hasta ahí puede bajar la cadera al sentarse.
		haunch = bodyY + 0.04 - 0.4,
	}
end

-- Studs por celda de los felinos voxel a escala 1: el cuerpo (18 celdas) mide lo que el del felino
-- redondo (2 studs), así los desplazamientos de sus clips siguen valiendo.
local VOXEL = 0.11

-- Lo único que necesitan los ayudantes de abajo de un kit de bloques: colocar una caja.
type Kit = { box: (list: { BasePart }?, name: string, center: Vector3, size: Vector3, color: Color3) -> BasePart }

-- Escalones de bloques alineados entre dos puntos (lo que antes era una viga inclinada: una cola, una pluma larga).
-- Cada tramo mide lo que avanza más el grosor, y así la figura entra en la malla de la mascota (Fase 21, Q5).
-- "width" es (ancho en X, grosor en Y); "segment" es lo que avanza cada escalón (1,8 celdas por defecto).
local function voxelStairs(
	v: Kit,
	list: { BasePart }?,
	name: string,
	from: Vector3,
	to: Vector3,
	width: Vector2,
	color: Color3,
	segment: number?
)
	local delta = to - from
	local count = math.max(1, math.ceil(math.max(math.abs(delta.Y), math.abs(delta.Z)) / (segment or 1.8)))
	for i = 0, count - 1 do
		local a = from + delta * (i / count)
		local b = from + delta * ((i + 1) / count)
		local size = Vector3.new(
			width.X + math.abs(b.X - a.X),
			math.abs(b.Y - a.Y) + width.Y,
			math.max(math.abs(b.Z - a.Z), width.Y)
		)
		v.box(list, name, (a + b) / 2, size, color)
	end
end

-- Plumas pintadas: filas de láminas finas desencajadas sobre una cara (la textura de la malla las pinta sin coste).
-- Con face "z" la cara mira hacia -Z o +Z (plano z = at.Z, "area" = ancho en X y alto en Y centrado en at); con "x"
-- mira hacia un lado (plano x = at.X, "area" = largo en Z y alto en Y). "cell" es el tamaño de cada pluma y "colors"
-- los tonos que se reparten.
local function voxelScales(
	v: Kit,
	list: { BasePart }?,
	name: string,
	face: string,
	at: Vector3,
	area: Vector2,
	cell: Vector2,
	colors: { Color3 },
	depth: number?
)
	local rows = math.max(1, math.floor(area.Y / cell.Y + 0.01))
	local cols = math.max(1, math.floor(area.X / cell.X + 0.01))
	local thick = depth or 0.2
	for r = 0, rows - 1 do
		local y = at.Y + area.Y / 2 - (r + 0.5) * cell.Y
		for c = 0, cols - 1 do
			local u = -area.X / 2 + (c + 0.5) * cell.X + (if r % 2 == 1 then cell.X * 0.5 else 0)
			if math.abs(u) + cell.X * 0.45 <= area.X / 2 + 0.3 then
				local color = colors[(r + c) % #colors + 1]
				if face == "z" then
					v.box(
						list,
						name,
						Vector3.new(at.X + u, y, at.Z),
						Vector3.new(cell.X * 0.85, cell.Y * 0.8, thick),
						color
					)
				else
					v.box(
						list,
						name,
						Vector3.new(at.X, y, at.Z + u),
						Vector3.new(thick, cell.Y * 0.8, cell.X * 0.85),
						color
					)
				end
			end
		end
	end
end

-- Escamas o plumas pintadas sobre una cara de arriba (plano y = at.Y, "area" = ancho en X y largo en Z centrado en at,
-- "cell" = tamaño de cada una en X y Z). El grosor "depth" va en Y.
local function voxelTopScales(
	v: Kit,
	list: { BasePart }?,
	name: string,
	at: Vector3,
	area: Vector2,
	cell: Vector2,
	colors: { Color3 },
	depth: number?
)
	local rows = math.max(1, math.floor(area.Y / cell.Y + 0.01))
	local cols = math.max(1, math.floor(area.X / cell.X + 0.01))
	for r = 0, rows - 1 do
		local z = at.Z - area.Y / 2 + (r + 0.5) * cell.Y
		for c = 0, cols - 1 do
			local u = -area.X / 2 + (c + 0.5) * cell.X + (if r % 2 == 1 then cell.X * 0.5 else 0)
			if math.abs(u) + cell.X * 0.45 <= area.X / 2 + 0.3 then
				v.box(
					list,
					name,
					Vector3.new(at.X + u, at.Y, z),
					Vector3.new(cell.X * 0.85, depth or 0.2, cell.Y * 0.85),
					colors[(r + c) % #colors + 1]
				)
			end
		end
	end
end

-- Extremidad gruesa que baja en diagonal entre dos puntos (un brazo, una pata) en escalones de bloques alineados:
-- cada tramo mide el grosor "thickness" y lo que avanza en Y y en Z, para que la figura entre en la malla (Q5).
local function voxelLimb(
	v: Kit,
	list: { BasePart }?,
	name: string,
	from: Vector3,
	to: Vector3,
	thickness: number,
	color: Color3,
	segment: number?
)
	local delta = to - from
	local count = math.max(1, math.ceil(math.max(math.abs(delta.Y), math.abs(delta.Z)) / (segment or 2)))
	for i = 0, count - 1 do
		local a = from + delta * (i / count)
		local b = from + delta * ((i + 1) / count)
		v.box(
			list,
			name,
			(a + b) / 2,
			Vector3.new(thickness + math.abs(b.X - a.X), math.abs(b.Y - a.Y) + 0.6, thickness + math.abs(b.Z - a.Z)),
			color
		)
	end
end

-- Tira plana en el suelo entre dos puntos (un dedo): escalones alineados que avanzan en X y en Z.
local function voxelFlat(
	v: Kit,
	list: { BasePart }?,
	name: string,
	from: Vector3,
	to: Vector3,
	width: number,
	height: number,
	color: Color3
)
	local delta = to - from
	local count = math.max(1, math.ceil(math.max(math.abs(delta.X), math.abs(delta.Z)) / 1))
	for i = 0, count - 1 do
		local a = from + delta * (i / count)
		local b = from + delta * ((i + 1) / count)
		v.box(
			list,
			name,
			(a + b) / 2,
			Vector3.new(math.max(math.abs(b.X - a.X), width), height, math.max(math.abs(b.Z - a.Z), width)),
			color
		)
	end
end

-- Felino en estilo voxel (bloques grandes, como la referencia del ocelote en docs/img): cuerpo de
-- caja con el vientre claro, paletillas y ancas en bloque, cabeza cúbica con hocico cuadrado, orejas
-- oscuras, patas en columna con dedos marcados y cola recta por tramos. Mismos huesos y medidas
-- ("dims") que "cat", así que usa los mismos clips. Medidas en celdas, con el suelo en y = 0.
-- Colores que cambia una skin de la familia (SKINS, "tone"): "coat" (pelaje), "spots" (manchas, rayas,
-- anillos y punta de la cola; con ella también los lleva el jaguarundí), "belly", "muzzle", "paw",
-- "toe" (las rendijas de los dedos) y "eye". Con el pelaje de una skin, el de cristal deja de ser de hielo.
local function voxelCat(rig: Rig, coat: Color3, options: CatOptions)
	local palette = rig.palette
	local skinned = palette ~= nil and palette.coat ~= nil
	coat = tone(rig, "coat", coat)
	local crystal = options.crystal == true
	local glassy = crystal and not skinned
	local slim = options.slim == true
	local spots = if palette and palette.spots then palette.spots else options.spots
	local material = if glassy then Enum.Material.Glacier else Enum.Material.SmoothPlastic
	local light = coat:Lerp(WHITE, 0.45)
	local pale = coat:Lerp(WHITE, 0.22)
	local belly = tone(rig, "belly", if spots and not crystal then coat:Lerp(WHITE, 0.78) else coat:Lerp(WHITE, 0.18))
	local dark = coat:Lerp(BLACK, 0.55)
	local legH = if slim then 5.5 else 7
	local bodyH = if slim then 5 else 6
	local bodyW = if slim then 5 else 6
	local bodyL = if slim then 20 else 18
	local bottom = legH
	local top = legH + bodyH
	local centerY = legH + bodyH / 2

	-- Celdas (suelo en 0) a coordenadas del modelo (centro del cuerpo en 0).
	local function at(p: Vector3): Vector3
		return (p - Vector3.new(0, centerY, 0)) * VOXEL
	end
	local function box(list: { BasePart }?, name: string, center: Vector3, size: Vector3, color: Color3): BasePart
		local part = piece(rig, name, "Block", size * VOXEL, CFrame.new(at(center)), color, material)
		if list then
			table.insert(list, part)
		end
		return part
	end
	-- Placa fina pegada a una cara (manchas, ojos, rayas): "center" está en la cara, "u" y "v" son sus
	-- ejes y "lift" lo que sobresale (para apilar el ojo, la pupila…).
	local function flat(
		list: { BasePart }?,
		name: string,
		center: Vector3,
		normal: Vector3,
		u: Vector3,
		size: Vector2,
		color: Color3,
		lift: number?
	): BasePart
		local v = normal:Cross(u)
		local position = at(center + normal * (lift or 0.05))
		local part = piece(
			rig,
			name,
			"Block",
			Vector3.new(size.X, size.Y, 0.14) * VOXEL,
			CFrame.fromMatrix(position, u, v),
			color,
			if crystal and color == spots then Enum.Material.Neon else material
		)
		if list then
			table.insert(list, part)
		end
		return part
	end
	-- Motas en una cara, como las de la referencia: una rejilla de huecos de "step" celdas con una
	-- mancha al azar (cuadro, barra, L o parche tostado claro) en cada hueco que toque. Semilla fija:
	-- todas las mascotas iguales salen con las mismas manchas.
	local rng = Random.new(13)
	local function speckle(
		list: { BasePart }?,
		center: Vector3,
		normal: Vector3,
		u: Vector3,
		size: Vector2,
		step: number,
		chance: number
	)
		if not spots then
			return
		end
		-- El de cristal lleva menos: sus manchas brillan y además tiene los cristales.
		local odds = if crystal then chance * 0.6 else chance
		local v = normal:Cross(u)
		local nu, nv = math.max(1, math.floor(size.X / step)), math.max(1, math.floor(size.Y / step))
		for i = 1, nu do
			for j = 1, nv do
				if rng:NextNumber() < odds then
					local cu = (i - (nu + 1) / 2) * size.X / nu + rng:NextNumber(-0.3, 0.3)
					local cv = (j - (nv + 1) / 2) * size.Y / nv + rng:NextNumber(-0.3, 0.3)
					local p = center + u * cu + v * cv
					local kind = rng:NextInteger(1, 7)
					if kind <= 2 then
						flat(list, "Spot", p, normal, u, Vector2.new(0.9, 0.9), spots)
					elseif kind == 3 then
						flat(list, "Spot", p, normal, u, Vector2.new(1.5, 0.6), spots)
					elseif kind == 4 then
						flat(list, "Spot", p, normal, u, Vector2.new(0.6, 1.4), spots)
					elseif kind <= 6 then
						-- L: barra y una pata en un extremo, girada al azar.
						local flip = if rng:NextNumber() < 0.5 then -1 else 1
						flat(list, "Spot", p, normal, u, Vector2.new(1.4, 0.6), spots)
						flat(list, "Spot", p + u * flip * 0.4 + v * 0.5, normal, u, Vector2.new(0.6, 1.1), spots)
					elseif not crystal then
						flat(list, "Patch", p, normal, u, Vector2.new(1.3, 1), pale)
					end
				end
			end
		end
	end

	-- Tronco en dos bloques: el pecho, que manda el rumbo, y la cadera, algo más estrecha y recogida
	-- por abajo, que gira sobre la cintura al girar la mascota ("bend" de animate): la cadera y la cola
	-- se abren hacia dentro de la curva y la cabeza mira hacia ella, y el cuerpo se dobla en C como el
	-- de un felino de verdad. Las patas de atrás y la cola cuelgan de la cadera. La cadera entra un
	-- poco en el pecho para que no se abra una rendija al doblarse.
	local waist = 0.4
	local hipW = bodyW - 0.4
	local frontEnd = waist + 0.6
	box(
		nil,
		"Body",
		Vector3.new(0, centerY, (-bodyL / 2 + frontEnd) / 2),
		Vector3.new(bodyW, bodyH, bodyL / 2 + frontEnd),
		coat
	)
	local hipStart = waist - 1.2
	local hips = box(
		nil,
		"Hips",
		Vector3.new(0, (bottom + 0.4 + top) / 2, (hipStart + bodyL / 2) / 2),
		Vector3.new(hipW, bodyH - 0.4, bodyL / 2 - hipStart),
		coat
	)
	local waistHinge = CFrame.new(at(Vector3.new(0, centerY, waist)))
	local spine = joint(rig, hips, waistHinge, Vector3.yAxis, 0, 1, 0, false)
	spine.bend = -0.8
	-- Lo que va pegado a la cadera y no se mueve por su cuenta: gira con ella solo mientras se dobla.
	local hipParts: { BasePart } = {}
	rig.bend = { hinge = waistHinge, factor = -0.8, parts = hipParts }

	-- Franja baja de los costados y pecho claros, en los dos bloques.
	box(
		nil,
		"Belly",
		Vector3.new(0, bottom + 0.7, (-5.5 + waist) / 2),
		Vector3.new(bodyW + 0.1, 1.4, waist + 5.5),
		belly
	)
	box(
		hipParts,
		"Belly",
		Vector3.new(0, bottom + 1, (waist + 4.5) / 2),
		Vector3.new(hipW + 0.1, 1.2, 4.5 - waist),
		belly
	)
	box(nil, "Chest", Vector3.new(0, bottom + 1.5, -bodyL / 2 + 0.1), Vector3.new(bodyW - 2.2, 2.6, 0.4), belly)
	-- Pecho hondo detrás de las manos: la cintura queda recogida hacia las ancas, como un felino atlético.
	box(nil, "Ribcage", Vector3.new(0, bottom - 0.5, -bodyL / 2 + 5.5), Vector3.new(bodyW - 1, 1.2, 4.6), belly)
	-- Manchas del lomo y de los costados, cada una en su bloque.
	local backFrom, backTo = -6.75, bodyL / 2 - 0.75
	speckle(
		nil,
		Vector3.new(0, top, (backFrom + waist + 0.4) / 2),
		Vector3.yAxis,
		Vector3.zAxis,
		Vector2.new(waist + 0.4 - backFrom, bodyW - 1),
		1.9,
		0.85
	)
	speckle(
		hipParts,
		Vector3.new(0, top, (waist + 0.8 + backTo) / 2),
		Vector3.yAxis,
		Vector3.zAxis,
		Vector2.new(backTo - waist - 0.8, hipW - 1),
		1.9,
		0.85
	)
	for _, side in { -1, 1 } do
		speckle(
			nil,
			Vector3.new(side * bodyW / 2, centerY + 0.7, (-4.5 + waist + 0.4) / 2),
			Vector3.xAxis * side,
			Vector3.zAxis,
			Vector2.new(waist + 4.9, bodyH - 1.8),
			1.6,
			0.95
		)
		speckle(
			hipParts,
			Vector3.new(side * hipW / 2, (bottom + 1.8 + top - 0.2) / 2, (waist + 0.8 + 4) / 2),
			Vector3.xAxis * side,
			Vector3.zAxis,
			Vector2.new(3.2 - waist, top - bottom - 2),
			1.6,
			0.95
		)
	end

	-- Cabeza: caja con el hocico cuadrado delante y la mandíbula clara.
	local s = if slim then 0.8 else 1
	local headParts: { BasePart } = {}
	local headSize = Vector3.new(7, 5.5, 5.5) * s
	local head = Vector3.new(0, top + 0.5 * s, -bodyL / 2 - 2.5 * s)
	local front = head.Z - headSize.Z / 2
	local crown = head.Y + headSize.Y / 2
	local chin = head.Y - headSize.Y / 2
	box(headParts, "Head", head, headSize, coat)
	-- Cuello grueso: un bloque detrás de la cabeza que asoma sobre el lomo entre las paletillas.
	local nape = Vector3.new(0, top + 0.35, head.Z + headSize.Z / 2 + 1.3)
	box(headParts, "Nape", nape, Vector3.new(bodyW - 2.6, 1.1, 3.2), coat)
	-- Hocico y mandíbula claros en el ocelote; en el jaguarundí, la cara casi del color del cuerpo.
	local muzzleColor = tone(rig, "muzzle", if spots then light else coat:Lerp(WHITE, 0.15))
	box(
		headParts,
		"Jaw",
		Vector3.new(0, chin + 0.8 * s, head.Z - 0.5 * s),
		Vector3.new(headSize.X + 0.1, 1.6 * s, headSize.Z - 0.9 * s),
		muzzleColor
	)
	local muzzle = Vector3.new(0, chin + 1.2 * s, front - 0.9)
	local muzzleSize = Vector3.new(4 * s, 2.6 * s, 2)
	box(headParts, "Muzzle", muzzle, muzzleSize, muzzleColor)
	local snout = muzzle.Z - muzzleSize.Z / 2
	box(
		headParts,
		"Chin",
		Vector3.new(0, chin - 0.1, snout + 1.1),
		Vector3.new(2.6 * s, 0.7, 1.6),
		if crystal then light else belly
	)
	-- Nariz en la esquina de arriba del hocico (se ve de frente y desde arriba) y boca debajo.
	local noseColor = if crystal
		then spots or coat
		elseif spots then Color3.fromRGB(105, 50, 45)
		else coat:Lerp(BLACK, 0.6)
	box(
		headParts,
		"Nose",
		Vector3.new(0, muzzle.Y + muzzleSize.Y / 2 - 0.3 * s, snout + 0.4),
		Vector3.new(1.6 * s, 0.7 * s, 1.1),
		noseColor
	)
	flat(
		headParts,
		"Mouth",
		Vector3.new(0, muzzle.Y - 0.5 * s, snout),
		-Vector3.zAxis,
		Vector3.xAxis,
		Vector2.new(1.8 * s, 0.24),
		dark
	)
	-- Ojos en la cara de delante: parche claro debajo, ojo, pupila en rendija y raya oscura encima.
	local stripe = spots or dark
	for _, side in { -1, 1 } do
		local eye = Vector3.new(side * 1.75 * s, head.Y + 0.55 * s, front)
		flat(
			headParts,
			"EyeMark",
			eye + Vector3.new(0, -0.6 * s, 0),
			-Vector3.zAxis,
			Vector3.xAxis,
			Vector2.new(1.6 * s, 0.7 * s),
			if crystal then light else belly
		)
		flat(
			headParts,
			"Eye",
			eye,
			-Vector3.zAxis,
			Vector3.xAxis,
			Vector2.new(1.5 * s, 0.8 * s),
			tone(rig, "eye", options.eyeColor),
			0.1
		).Material = if crystal
			then Enum.Material.Neon
			else Enum.Material.SmoothPlastic
		flat(
			headParts,
			"Pupil",
			eye,
			-Vector3.zAxis,
			Vector3.xAxis,
			Vector2.new(0.35 * s, 0.8 * s),
			if glassy then Color3.fromRGB(20, 60, 120) else BLACK,
			0.16
		)
		flat(
			headParts,
			"EyeLine",
			eye + Vector3.new(side * 0.15, 0.6 * s, 0),
			-Vector3.zAxis,
			Vector3.xAxis,
			Vector2.new(1.8 * s, 0.32 * s),
			if crystal then dark else BLACK
		)
		-- Rayas de la mejilla, del rabillo del ojo hacia atrás.
		if spots then
			local cheek = Vector3.new(side * headSize.X / 2, head.Y, front)
			flat(
				headParts,
				"CheekStripe",
				cheek + Vector3.new(0, 0.1 * s, 1.9 * s),
				Vector3.xAxis * side,
				Vector3.zAxis,
				Vector2.new(2.8 * s, 0.45 * s),
				stripe
			)
			flat(
				headParts,
				"CheekStripe",
				cheek + Vector3.new(0, -0.9 * s, 1.6 * s),
				Vector3.xAxis * side,
				Vector3.zAxis,
				Vector2.new(2 * s, 0.4 * s),
				stripe
			)
		end
		-- Orejas: bloques oscuros (claras por dentro) con la mancha blanca detrás del ocelote.
		local earSize = if options.roundEars then Vector3.new(1.6, 1.3, 1) * s else Vector3.new(2, 1.8, 1.2) * s
		local ear = Vector3.new(side * (headSize.X / 2 - 1.1 * s), crown + earSize.Y / 2, head.Z + 0.6 * s)
		box(headParts, "Ear", ear, earSize, if spots and not crystal then dark:Lerp(BLACK, 0.4) else coat)
		flat(
			headParts,
			"InnerEar",
			ear - Vector3.new(0, 0.15 * s, earSize.Z / 2),
			-Vector3.zAxis,
			Vector3.xAxis,
			Vector2.new(earSize.X * 0.45, earSize.Y * 0.45),
			if crystal then spots or light else pale
		)
		if spots and not crystal then
			flat(
				headParts,
				"EarSpot",
				ear + Vector3.new(0, -0.1, earSize.Z / 2),
				Vector3.zAxis,
				Vector3.xAxis,
				Vector2.new(0.9, 0.8),
				WHITE
			)
		end
	end
	if spots then
		-- Dos rayas paralelas desde la frente por encima de la cabeza hasta la nuca.
		for _, x in { -0.65 * s, 0.65 * s } do
			local rise = crown - (head.Y + 1.3 * s)
			flat(
				headParts,
				"HeadStripe",
				Vector3.new(x, crown - rise / 2, front),
				-Vector3.zAxis,
				Vector3.xAxis,
				Vector2.new(0.45, rise),
				stripe
			)
			flat(
				headParts,
				"HeadStripe",
				Vector3.new(x, crown, head.Z),
				Vector3.yAxis,
				Vector3.zAxis,
				Vector2.new(headSize.Z, 0.45),
				stripe
			)
			flat(
				headParts,
				"NeckStripe",
				Vector3.new(x, nape.Y + 0.55, nape.Z),
				Vector3.yAxis,
				Vector3.zAxis,
				Vector2.new(3, 0.45),
				stripe
			)
		end
	end

	-- Patas en columna de dos tramos (hombro o anca con el de arriba) y pie claro con dos rendijas entre
	-- los dedos. El tramo de abajo cuelga del de arriba y se dobla al avanzar, como en "cat".
	local knee = legH * 0.5
	local hipY = centerY
	local paw = tone(rig, "paw", coat:Lerp(WHITE, if spots then 0.32 else 0.12))
	local toeColor = tone(rig, "toe", dark)
	-- Tono algo más oscuro para los músculos que abultan: marca la sombra entre ellos.
	local muscle = coat:Lerp(BLACK, 0.12)
	local phases = { 0, math.pi, math.pi, 0 }
	local bones = { "FL", "FR", "BL", "BR" }
	local zFront, zBack = -(bodyL / 2 - 2.5), bodyL / 2 - 2.5
	for i, spot in { { -1, true }, { 1, true }, { -1, false }, { 1, false } } do
		local side: number, isFront: boolean = spot[1], spot[2]
		local width = if isFront then 2.5 else 2.7
		local x = side * (bodyW / 2 - 1.3)
		local z = if isFront then zFront else zBack
		local outward = Vector3.xAxis * side
		local upper: { BasePart } = {}
		local lower: { BasePart } = {}
		-- Paletilla o anca: bloque que sobresale un poco del costado.
		-- Hombro (deltoides) con el omóplato encima, más estrecho y algo más claro, que asoma sobre el
		-- lomo; detrás, el anca hasta el lomo con el glúteo y el muslo abultando hacia fuera en un tono
		-- más oscuro. Con un solo color, los bloques parecían tablones: los escalones de tono son los que
		-- dejan leer el músculo.
		local mass: Vector3
		local massSize: Vector3
		local face: Vector3
		local faceSize: Vector2
		if isFront then
			massSize = Vector3.new(2.5, bodyH - 1.6, 4)
			mass = Vector3.new(side * (bodyW / 2 - 1), bottom + 0.4 + massSize.Y / 2, z - 0.3)
			box(upper, "Shoulder", mass, massSize, coat)
			local blade = mass.Y + massSize.Y / 2 - 0.5
			box(
				upper,
				"Scapula",
				Vector3.new(side * (bodyW / 2 - 1.5), (blade + top + 0.45) / 2, z - 0.1),
				Vector3.new(2, top + 0.45 - blade, 2.6),
				coat:Lerp(WHITE, 0.08)
			)
			face, faceSize = mass, Vector2.new(massSize.Z - 0.6, massSize.Y - 0.8)
		else
			massSize = Vector3.new(2.6, top - bottom + 0.45, 4.6)
			mass = Vector3.new(side * (bodyW / 2 - 1), (bottom - 0.2 + top + 0.25) / 2, z + 0.3)
			box(upper, "Haunch", mass, massSize, coat)
			box(
				upper,
				"Glute",
				Vector3.new(side * (bodyW / 2 + 0.45), bottom + 1.3, z + 0.5),
				Vector3.new(0.7, 3.4, 3.6),
				muscle
			)
			-- Las manchas del anca, por encima del glúteo.
			local low = bottom + 3
			face = Vector3.new(mass.X, (low + top + 0.25) / 2, mass.Z)
			faceSize = Vector2.new(massSize.Z - 0.6, top + 0.25 - low - 0.6)
		end
		speckle(upper, face + outward * massSize.X / 2, outward, Vector3.zAxis, faceSize, 1.6, 0.8)
		if not isFront then
			-- Las ancas por detrás, que es lo que más se ve mientras sigue al dueño.
			speckle(
				upper,
				mass + Vector3.zAxis * massSize.Z / 2,
				Vector3.zAxis,
				Vector3.xAxis,
				Vector2.new(massSize.X - 0.6, massSize.Y - 1),
				1.3,
				0.7
			)
		end
		-- Tramo de arriba grueso, con el muslo de atrás abultando por detrás en las patas de atrás; el
		-- de abajo más fino, con el antebrazo o el gemelo arriba: la muñeca se estrecha.
		local upperTop = bottom + 1
		local thick = width + (if isFront then 0.4 else 0.5)
		box(
			upper,
			if isFront then "UpperArm" else "Thigh",
			Vector3.new(x, (knee + upperTop) / 2, z),
			Vector3.new(thick, upperTop - knee, thick),
			coat
		)
		if not isFront then
			box(
				upper,
				"Hamstring",
				Vector3.new(x, bottom - 0.4, z + thick / 2 + 0.3),
				Vector3.new(width, 2.6, 1.2),
				muscle
			)
		end
		-- Manchas en lo que asoma del tramo de arriba, por fuera.
		speckle(
			upper,
			Vector3.new(x, (knee + bottom) / 2 - 0.2, z) + outward * thick / 2,
			outward,
			Vector3.zAxis,
			Vector2.new(thick - 0.9, bottom - knee - 0.8),
			1.3,
			0.6
		)
		local shin = width - 0.6
		box(
			lower,
			if isFront then "Forearm" else "Shin",
			Vector3.new(x, (1.2 + knee + 0.3) / 2, z),
			Vector3.new(shin, knee + 0.3 - 1.2, shin),
			coat
		)
		if isFront then
			box(lower, "ForearmMuscle", Vector3.new(x, knee - 0.4, z - 0.1), Vector3.new(width, 1.6, width), coat)
		else
			box(
				lower,
				"Calf",
				Vector3.new(x, knee - 0.5, z + shin / 2 + 0.35),
				Vector3.new(width - 0.4, 1.8, 1),
				muscle
			)
		end
		speckle(
			lower,
			Vector3.new(x + side * shin / 2, knee / 2, z),
			outward,
			Vector3.zAxis,
			Vector2.new(shin - 0.5, knee - 2.4),
			1.2,
			0.7
		)
		local pawCenter = Vector3.new(x, 0.65, z - 0.5)
		local pawSize = Vector3.new(width + 0.5, 1.3, 3.4)
		box(lower, "Paw", pawCenter, pawSize, paw)
		for _, toe in { -1, 1 } do
			-- Rendija oscura que cruza la punta del pie por delante y por arriba.
			box(
				lower,
				"Toe",
				pawCenter + Vector3.new(toe * pawSize.X / 6, 0.15, -pawSize.Z / 2 + 0.6),
				Vector3.new(0.2, pawSize.Y - 0.2, 1.3),
				toeColor
			)
		end
		local thigh: Joint? = nil
		for _, part in upper do
			thigh = joint(
				rig,
				part,
				CFrame.new(at(Vector3.new(x, hipY, z))),
				Vector3.xAxis,
				0.45,
				9,
				phases[i],
				true,
				nil,
				if isFront then nil else spine
			)
			thigh.bone = bones[i]
		end
		for _, part in lower do
			local item = joint(
				rig,
				part,
				CFrame.new(at(Vector3.new(x, knee, z))),
				Vector3.xAxis,
				-0.3,
				9,
				phases[i] + math.pi / 2,
				true,
				-0.3,
				thigh
			)
			item.bone = bones[i] .. "2"
		end
	end

	-- Cola recta por tramos que sube un poco y se estira: anillos oscuros y punta oscura (ocelote).
	local tailWidth = if slim then 2 else 1.8
	local rises = if slim then { 0.3, 0.12, 0, -0.08, -0.12 } else { 0.6, 0.4, 0.22, 0.1 }
	local segment = if slim then 3 else 2.8
	local from = Vector3.new(0, top - 1, bodyL / 2 - 0.5)
	local previous: Joint? = spine
	for i, rise in rises do
		local direction = Vector3.new(0, rise, 1).Unit
		local to = from + direction * segment
		local frame = CFrame.lookAt(at((from + to) / 2), at(to))
		local parts = {
			piece(
				rig,
				"Tail",
				"Block",
				Vector3.new(tailWidth, tailWidth, segment + 0.6) * VOXEL,
				frame,
				coat,
				material
			),
		}
		local band = if crystal then nil else spots
		if band and i > 1 then
			table.insert(
				parts,
				piece(
					rig,
					"TailBand",
					"Block",
					Vector3.new(tailWidth + 0.2, tailWidth + 0.2, 0.8) * VOXEL,
					frame,
					band,
					material
				)
			)
		end
		if i == #rises then
			local tip = frame * CFrame.new(0, 0, -(segment / 2 + 0.05) * VOXEL)
			local tipPart = piece(
				rig,
				"TailTip",
				"Block",
				Vector3.new(tailWidth + 0.1, tailWidth + 0.1, 1.1) * VOXEL,
				tip,
				if spots then spots else coat:Lerp(BLACK, 0.15),
				if crystal then Enum.Material.Neon else material
			)
			table.insert(parts, tipPart)
		end
		local last: Joint? = nil
		for _, part in parts do
			local item = joint(
				rig,
				part,
				CFrame.new(at(from)),
				Vector3.yAxis,
				0.5 * 0.3,
				5,
				-(i - 1) * 0.55,
				false,
				nil,
				previous
			)
			item.bone = "Tail"
			item.lag = i - 1
			last = item
		end
		previous = last
		from = to
	end

	if glassy then
		for _, part in rig.model:GetChildren() do
			if part:IsA("BasePart") and part.Material == material then
				part.Transparency = 0.15
			end
		end
	end
	-- La cabeza mira despacio a un lado y a otro, girando sobre la nuca.
	local neck = CFrame.new(at(Vector3.new(0, top - 1, -bodyL / 2 + 1.5)))
	for _, part in headParts do
		local item = joint(rig, part, neck, Vector3.yAxis, 0.25, 0.9, 0, false)
		item.bone = "Head"
		-- Mira hacia donde gira.
		item.bend = 0.5
	end
	rig.family = "Cat"
	rig.dims = {
		length = bodyL * VOXEL,
		legHeight = legH * VOXEL,
		bodyY = 0,
		ground = at(Vector3.zero).Y,
		hips = at(Vector3.new(0, hipY, zBack)),
		shoulders = at(Vector3.new(0, hipY, zFront)),
		center = Vector3.zero,
		haunch = at(Vector3.new(0, bottom - 0.2, 0)).Y,
		-- Medio alto y medio ancho del cuerpo, para tumbarlo y ponerlo panza arriba sin que se hunda.
		halfHeight = bodyH / 2 * VOXEL,
		halfWidth = (bodyW / 2 + 0.3) * VOXEL,
	}
end

-- Cristales del Jaguar de cristal voxel: bloques de vidrio escalonados que se estrechan hacia la
-- punta, con un núcleo que brilla dentro, en el lomo, los hombros y la frente (este gira con la
-- cabeza). Medidas en studs a escala 1, sobre el cuerpo de voxelCat.
local function voxelCrystals(rig: Rig, color: Color3, glow: Color3)
	local function crystal(base: Vector3, tilt: Vector3, height: number, width: number): { BasePart }
		local frame = CFrame.new(base) * CFrame.Angles(tilt.X, tilt.Y, tilt.Z)
		local parts = {}
		for step, size in { Vector3.new(1, 0.5, 1), Vector3.new(0.62, 0.42, 0.62), Vector3.new(0.3, 0.3, 0.3) } do
			local y = ({ 0.25, 0.68, 0.93 })[step]
			local shell = piece(
				rig,
				"Crystal",
				"Block",
				Vector3.new(size.X * width, size.Y * height, size.Z * width),
				frame * CFrame.new(0, y * height, 0),
				color:Lerp(glow, 0.55),
				Enum.Material.Glass
			)
			shell.Transparency = 0.2
			table.insert(parts, shell)
		end
		table.insert(
			parts,
			piece(
				rig,
				"CrystalCore",
				"Block",
				Vector3.new(width * 0.3, height * 0.75, width * 0.3),
				frame * CFrame.new(0, height * 0.38, 0),
				glow,
				Enum.Material.Neon
			)
		)
		-- Los de detrás de la cintura se doblan con la cadera.
		local bend = rig.bend
		if bend and base.Z > 0.05 then
			for _, part in parts do
				table.insert(bend.parts, part)
			end
		end
		return parts
	end
	-- Lomo, de delante atrás y cada vez más bajos, alternando un poco de lado.
	crystal(Vector3.new(0.06, 0.3, -0.5), Vector3.new(-0.15, 0, -0.12), 0.62, 0.24)
	crystal(Vector3.new(-0.08, 0.3, -0.08), Vector3.new(0.1, 0, 0.2), 0.5, 0.22)
	crystal(Vector3.new(0.05, 0.3, 0.35), Vector3.new(0.2, 0, -0.15), 0.42, 0.2)
	crystal(Vector3.new(-0.03, 0.3, 0.72), Vector3.new(0.3, 0, 0.1), 0.3, 0.16)
	for _, side in { -1, 1 } do
		crystal(Vector3.new(side * 0.34, 0.15, -0.72), Vector3.new(0, 0, -side * 0.7), 0.34, 0.16)
	end
	-- En la frente, inclinado hacia delante: gira con la cabeza (bisagra de la nuca de voxelCat).
	for _, part in crystal(Vector3.new(0, 0.66, -1.42), Vector3.new(-0.5, 0, 0), 0.28, 0.16) do
		local item = joint(rig, part, CFrame.new(0, 0.22, -0.825), Vector3.yAxis, 0.25, 0.9, 0, false)
		item.bone = "Head"
		item.bend = 0.5
	end
end

-- Felinos en estilo voxel (voxelCat, aprobado el 18-10-2026) o redondos (cat, el modelo de antes).
PetModels.voxelCats = true

local function felid(rig: Rig, coat: Color3, options: CatOptions)
	if PetModels.voxelCats then
		voxelCat(rig, coat, options)
	else
		cat(rig, coat, options)
	end
end

-- Medidas de cada raza de perro voxel (celdas de VOXEL, como los felinos) y sus colores por zona.
type DogPatch = { center: Vector3, size: Vector3, hips: boolean? }
type DogOptions = {
	legH: number, -- alto de las patas
	legW: number, -- grosor de las patas de delante (las de atrás, algo más)
	bodyH: number,
	bodyW: number,
	bodyL: number,
	tuck: number, -- cuánto sube la barriga en la cadera (cintura recogida)
	skull: Vector3, -- la cabeza sin el hocico
	snout: Vector3, -- el hocico (su largo en Z)
	neck: number, -- cuánto sube el centro de la cabeza sobre el lomo
	ear: Vector3, -- oreja caída: grosor, largo hacia abajo y ancho
	tail: { Vector3 }, -- dirección de cada tramo de la cola, de la base a la punta (Z = hacia atrás)
	tailSegment: number,
	tailWidth: number,
	tailTaper: number, -- lo que adelgaza cada tramo (la cola de nutria del labrador es gruesa en la base)
	eye: Color3,
	nose: Color3,
	-- Colores por zona; sin ellos, los del pelaje: manto del lomo, cabeza y cuello, orejas, hocico,
	-- lista de la frente, pecho y vientre, tramo de abajo de las patas, cola y punta de la cola.
	saddle: Color3?,
	head: Color3?,
	ears: Color3?,
	muzzle: Color3?,
	blaze: Color3?,
	chest: Color3?,
	legs: Color3?,
	tailColor: Color3?,
	tailTip: Color3?,
	-- Manchas grandes (pointer): cajas que asoman del cuerpo, en celdas; "hips" si van en la cadera.
	patches: ((top: number, bottom: number) -> { DogPatch })?,
	patchColor: Color3?,
	ticking: Color3?, -- moteado fino (pointer)
	collar: Color3?,
	tongue: boolean?,
	faceEdge: number?, -- chaflán de la cara del cráneo (por defecto el del cráneo): un cráneo grande necesita la cara más ancha para que quepan los ojos
	skullChamfer: number?, -- chaflán del cráneo (por defecto, según su ancho)
	accent: Color3?, -- manchas de contraste de la cara (ceja, mejilla, labio) en la versión con malla
	iris: Color3?, -- iris del ojo, si se quiere que contraste con la cabeza
	pack: Color3?, -- alforjas de perro a los lados del lomo (labrador: la mascota que trae botín)
}

-- Perro en estilo voxel (Grupo 15; fotos en docs/img). Mismos huesos y medidas ("dims") que los
-- felinos voxel: pecho que manda el rumbo y cadera que se dobla al girar, patas de dos tramos, cola por
-- tramos y cabeza que gira sobre la nuca; además, las orejas caídas, que van con la cabeza y aletean al
-- trote (huesos "EarL" y "EarR"). Frente al felino: patas más largas, pecho hondo con quilla y la
-- cintura recogida, cuello que sube y lleva la cabeza por encima del lomo, hocico largo con la trufa
-- delante y corvejón en las patas de atrás (el tramo de abajo va más atrás que el muslo). Medidas en
-- celdas, con el suelo en y = 0.
local function voxelDog(rig: Rig, coat: Color3, o: DogOptions)
	local material = Enum.Material.SmoothPlastic
	local legH, bodyH, bodyW, bodyL = o.legH, o.bodyH, o.bodyW, o.bodyL
	local bottom = legH
	local top = legH + bodyH
	local centerY = legH + bodyH / 2
	local headColor = o.head or coat
	local chest = o.chest or coat:Lerp(WHITE, 0.2)
	local legColor = o.legs or coat
	local dark = headColor:Lerp(BLACK, 0.6)
	-- Escalones de tono de los músculos (aprendido en los felinos): hombro apenas más claro (con un +8 %
	-- parecía un tablón pegado al costado) y muslo más oscuro.
	local shoulderColor = coat:Lerp(WHITE, 0.04)
	local muscle = coat:Lerp(BLACK, 0.12)

	local function at(p: Vector3): Vector3
		return (p - Vector3.new(0, centerY, 0)) * VOXEL
	end
	local function box(list: { BasePart }?, name: string, center: Vector3, size: Vector3, color: Color3): BasePart
		local part = piece(rig, name, "Block", size * VOXEL, CFrame.new(at(center)), color, material)
		if list then
			table.insert(list, part)
		end
		return part
	end
	-- Placa fina pegada a una cara (ojos, lista, moteado): "center" está en la cara, "u" es su eje
	-- horizontal y "lift" lo que sobresale.
	local function flat(
		list: { BasePart }?,
		name: string,
		center: Vector3,
		normal: Vector3,
		u: Vector3,
		size: Vector2,
		color: Color3,
		lift: number?
	): BasePart
		local v = normal:Cross(u)
		local part = piece(
			rig,
			name,
			"Block",
			Vector3.new(size.X, size.Y, 0.14) * VOXEL,
			CFrame.fromMatrix(at(center + normal * (lift or 0.05)), u, v),
			color,
			material
		)
		if list then
			table.insert(list, part)
		end
		return part
	end
	-- Moteado fino del pointer: una rejilla de huecos de "step" celdas con una mota al azar en los que
	-- toque. Semilla fija: todos los pointer salen con las mismas motas.
	local rng = Random.new(29)
	local function ticking(
		list: { BasePart }?,
		center: Vector3,
		normal: Vector3,
		u: Vector3,
		size: Vector2,
		step: number
	)
		local color = o.ticking
		if not color then
			return
		end
		local v = normal:Cross(u)
		local nu, nv = math.max(1, math.floor(size.X / step)), math.max(1, math.floor(size.Y / step))
		for i = 1, nu do
			for j = 1, nv do
				if rng:NextNumber() < 0.6 then
					local cu = (i - (nu + 1) / 2) * size.X / nu + rng:NextNumber(-0.4, 0.4)
					local cv = (j - (nv + 1) / 2) * size.Y / nv + rng:NextNumber(-0.4, 0.4)
					local dot = rng:NextNumber(0.35, 0.6)
					flat(list, "Tick", center + u * cu + v * cv, normal, u, Vector2.new(dot, dot), color)
				end
			end
		end
	end

	-- Textura de pelo y detalles finos (Fase 21, Q5): solo en el perro sin skin, que es el que lleva malla; con skin se
	-- queda el modelo de siempre. Todo lo fino va pintado en la textura de la malla.
	local rich = rig.palette == nil
	local kit: Kit = { box = box }
	local function tones(base: Color3): { Color3 }
		-- En un tono casi negro, ±10 % no se ve: los mechones se aclaran hacia un gris cálido.
		if base.R + base.G + base.B < 0.55 then
			local warm = Color3.fromRGB(110, 98, 92)
			return { base, base:Lerp(warm, 0.22), base:Lerp(warm, 0.4), base:Lerp(warm, 0.12) }
		end
		return { base, base:Lerp(BLACK, 0.1), base:Lerp(WHITE, 0.1), base:Lerp(BLACK, 0.04) }
	end
	local topColor = o.saddle or coat

	-- Tronco: el pecho, que manda el rumbo, y la cadera, más estrecha y recogida por abajo, que gira
	-- sobre la cintura al girar (como el felino). Bajo el pecho, la quilla: el pecho hondo del perro.
	local waist = 0.4
	local hipW = bodyW - 0.4
	local chestFront = -bodyL / 2
	local frontEnd = waist + 0.6
	box(
		nil,
		"Body",
		Vector3.new(0, centerY, (chestFront + frontEnd) / 2),
		Vector3.new(bodyW, bodyH, frontEnd - chestFront),
		coat
	)
	local hipStart = waist - 1.2
	local hipBottom = bottom + o.tuck
	local hips = box(
		nil,
		"Hips",
		Vector3.new(0, (hipBottom + top) / 2, (hipStart + bodyL / 2) / 2),
		Vector3.new(hipW, top - hipBottom, bodyL / 2 - hipStart),
		coat
	)
	local waistHinge = CFrame.new(at(Vector3.new(0, centerY, waist)))
	local spine = joint(rig, hips, waistHinge, Vector3.yAxis, 0, 1, 0, false)
	spine.bend = -0.8
	local hipParts: { BasePart } = {}
	rig.bend = { hinge = waistHinge, factor = -0.8, parts = hipParts }

	local keelLength = bodyL * 0.34
	box(
		nil,
		"Keel",
		Vector3.new(0, bottom - 0.5, chestFront + 1.2 + keelLength / 2),
		Vector3.new(bodyW - 1.4, 1.2, keelLength),
		chest
	)
	box(
		nil,
		"Belly",
		Vector3.new(0, bottom + 0.6, (chestFront + 0.6 + frontEnd) / 2),
		Vector3.new(bodyW + 0.1, 1.2, frontEnd - chestFront - 0.6),
		chest
	)
	box(
		hipParts,
		"Belly",
		Vector3.new(0, hipBottom + 0.45, (hipStart + bodyL / 2 - 3.2) / 2),
		Vector3.new(hipW + 0.1, 0.9, bodyL / 2 - 3.2 - hipStart),
		chest
	)
	box(
		nil,
		"Chest",
		Vector3.new(0, bottom + bodyH * 0.32, chestFront - 0.1),
		Vector3.new(bodyW - 2.4, bodyH * 0.6, 0.4),
		chest
	)

	-- Manto negro del lomo (beagle): de detrás de los hombros hasta la cola, por arriba y por los costados.
	if o.saddle then
		local depth = bodyH * 0.6
		local y = top - depth / 2 + 0.06
		local from = chestFront + 3.4
		box(
			nil,
			"Saddle",
			Vector3.new(0, y, (from + frontEnd) / 2),
			Vector3.new(bodyW + 0.12, depth, frontEnd - from),
			o.saddle
		)
		local to = bodyL / 2 - 0.4
		box(
			hipParts,
			"Saddle",
			Vector3.new(0, y, (hipStart + to) / 2),
			Vector3.new(hipW + 0.12, depth, to - hipStart),
			o.saddle
		)
	end
	if o.patches then
		for _, mark in o.patches(top, bottom) do
			box(if mark.hips then hipParts else nil, "Patch", mark.center, mark.size, o.patchColor or BLACK)
		end
	end
	if rich then
		-- Cruz, grupa y pecho en relieve, y el pelo pintado por el lomo, los costados, la grupa y el pecho. Lo de la
		-- cadera va con la articulación de la cintura ("spine": grupo J1 de la malla).
		local spineParts: { BasePart } = {}
		local midZ = (chestFront + frontEnd) / 2
		local hipMid = (hipStart + bodyL / 2) / 2
		box(nil, "Withers", Vector3.new(0, top + 0.35, chestFront + 3.9), Vector3.new(bodyW - 1.4, 0.7, 3.4), topColor)
		box(
			spineParts,
			"Croup",
			Vector3.new(0, top + 0.35, bodyL / 2 - 1.8),
			Vector3.new(hipW - 1.4, 0.7, 2.8),
			topColor
		)
		box(
			nil,
			"Brisket",
			Vector3.new(0, bottom + bodyH * 0.3, chestFront - 0.45),
			Vector3.new(bodyW - 3.2, bodyH * 0.45, 0.5),
			chest
		)
		local strandTop = tones(topColor)
		voxelTopScales(
			kit,
			nil,
			"Strand",
			Vector3.new(0, top + 0.06, midZ),
			Vector2.new(bodyW - 0.8, frontEnd - chestFront - 1),
			Vector2.new(1.16, 1.59),
			strandTop,
			0.12
		)
		voxelTopScales(
			kit,
			nil,
			"Strand",
			Vector3.new(0, top + 0.76, chestFront + 3.9),
			Vector2.new(bodyW - 1.8, 3),
			Vector2.new(1.16, 1.45),
			strandTop,
			0.12
		)
		voxelTopScales(
			kit,
			spineParts,
			"Strand",
			Vector3.new(0, top + 0.06, hipMid),
			Vector2.new(hipW - 0.8, bodyL / 2 - hipStart - 1),
			Vector2.new(1.16, 1.59),
			strandTop,
			0.12
		)
		voxelTopScales(
			kit,
			spineParts,
			"Strand",
			Vector3.new(0, top + 0.76, bodyL / 2 - 1.8),
			Vector2.new(hipW - 1.8, 2.4),
			Vector2.new(1.16, 1.45),
			strandTop,
			0.12
		)
		-- Costados: por debajo del manto si lo lleva.
		local sideH = if o.saddle then bodyH * 0.4 - 0.8 else bodyH - 1.4
		local hipH = math.max(
			1,
			(if o.saddle then top - bodyH * 0.6 else top) - (hipBottom + 0.8) - (if o.saddle then 0 else 0.6)
		)
		for _, side in { -1, 1 } do
			voxelScales(
				kit,
				nil,
				"Fur",
				"x",
				Vector3.new(side * (bodyW / 2 + 0.05), bottom + 0.8 + sideH / 2, midZ),
				Vector2.new(frontEnd - chestFront - 1.2, sideH),
				Vector2.new(1.59, 1.3),
				tones(coat),
				0.12
			)
			voxelScales(
				kit,
				spineParts,
				"Fur",
				"x",
				Vector3.new(side * (hipW / 2 + 0.05), hipBottom + 0.8 + hipH / 2, hipMid),
				Vector2.new(bodyL / 2 - hipStart - 1.2, hipH),
				Vector2.new(1.59, 1.3),
				tones(coat),
				0.12
			)
		end
		voxelScales(
			kit,
			spineParts,
			"Fur",
			"z",
			Vector3.new(0, (hipBottom + top) / 2, bodyL / 2 + 0.05),
			Vector2.new(hipW - 0.8, top - hipBottom - 1.2),
			Vector2.new(1.45, 1.3),
			tones(coat),
			0.12
		)
		voxelScales(
			kit,
			nil,
			"Fur",
			"z",
			Vector3.new(0, bottom + bodyH * 0.3, chestFront - 0.74),
			Vector2.new(bodyW - 3.6, bodyH * 0.42),
			Vector2.new(1.3, 1.3),
			tones(chest),
			0.12
		)
		for _, part in spineParts do
			local extra = joint(rig, part, waistHinge, Vector3.yAxis, 0, 1, 0, false)
			extra.bend = -0.8
		end
	end
	-- Alforjas: panel encima del lomo, detrás de la cruz, y una bolsa a cada lado con su tapa más
	-- oscura y una correa vertical con la hebilla abajo (así se leen como bolsas, no como una cara);
	-- la cincha rodea el pecho por detrás de las patas de delante.
	if o.pack then
		local strap = Color3.fromRGB(95, 65, 40)
		local buckle = Color3.fromRGB(235, 190, 60)
		local packFrom, packTo = chestFront + 4.2, frontEnd - 0.2
		local packZ = (packFrom + packTo) / 2
		local packL = packTo - packFrom
		box(nil, "PackTop", Vector3.new(0, top + 0.25, packZ), Vector3.new(bodyW - 0.6, 0.6, packL), o.pack)
		box(nil, "Girth", Vector3.new(0, centerY, packFrom - 0.2), Vector3.new(bodyW + 0.2, bodyH + 0.2, 0.7), strap)
		for _, side in { -1, 1 } do
			local x = side * (bodyW / 2 + 0.65)
			local pouchH = bodyH * 0.55
			local pouchY = top - 0.4 - pouchH / 2
			box(nil, "Pouch", Vector3.new(x, pouchY, packZ), Vector3.new(1.3, pouchH, packL - 0.4), o.pack)
			box(
				nil,
				"PouchFlap",
				Vector3.new(x + side * 0.08, top - 0.6, packZ),
				Vector3.new(1.3, 0.9, packL - 0.2),
				o.pack:Lerp(BLACK, 0.25)
			)
			box(nil, "PouchStrap", Vector3.new(x + side * 0.7, pouchY, packZ), Vector3.new(0.12, pouchH, 0.6), strap)
			box(
				nil,
				"PouchBuckle",
				Vector3.new(x + side * 0.75, pouchY - pouchH / 2 + 0.7, packZ),
				Vector3.new(0.14, 0.6, 0.8),
				buckle
			)
		end
	end
	-- Equipo de una skin (SKINS: lo pide su paleta, y así vale para los tres perros, con sus medidas):
	-- la camiseta de marinero a rayas en el pecho ("shirt" y "shirtStripe") y, a la espalda, el mástil con
	-- la bandera pirata ("flag"), que ondea; la calavera mira atrás y adelante, para verse de espaldas.
	local gear = rig.palette or {}
	if gear.shirt and gear.shirtStripe then
		local from, to = chestFront - 0.15, frontEnd - 0.4
		local shirtBottom, shirtTop = bottom - 0.2, top + 0.15
		local stripes = 6
		for index = 1, stripes do
			local height = (shirtTop - shirtBottom) / stripes
			box(
				nil,
				"Shirt",
				Vector3.new(0, shirtBottom + (index - 0.5) * height, (from + to) / 2),
				Vector3.new(bodyW + 0.3, height, to - from),
				if index % 2 == 0 then gear.shirtStripe else gear.shirt
			)
		end
	end
	if gear.flag then
		-- Medidas de la bandera en celdas (el doble que una bandera "de verdad" para un perro: más pequeña
		-- no se leía desde la cámara).
		local poleZ = (chestFront + frontEnd) / 2 + 1.5
		local poleH = 11
		box(
			nil,
			"FlagPole",
			Vector3.new(0, top + poleH / 2, poleZ),
			Vector3.new(0.7, poleH, 0.7),
			Color3.fromRGB(110, 75, 40)
		)
		box(
			nil,
			"FlagTip",
			Vector3.new(0, top + poleH + 0.5, poleZ),
			Vector3.new(1.1, 1, 1.1),
			Color3.fromRGB(235, 190, 60)
		)
		local flagParts: { BasePart } = {}
		local flagY, flagX = top + poleH - 2.3, 3.5
		box(flagParts, "Flag", Vector3.new(flagX, flagY, poleZ), Vector3.new(6.4, 4.2, 0.25), gear.flag)
		for _, face in { -1, 1 } do
			local z = poleZ + face * 0.2
			box(flagParts, "FlagSkull", Vector3.new(flagX, flagY + 0.5, z), Vector3.new(1.8, 1.5, 0.15), WHITE)
			box(flagParts, "FlagSkull", Vector3.new(flagX, flagY - 0.4, z), Vector3.new(1.1, 0.5, 0.15), WHITE)
			for _, eye in { -1, 1 } do
				box(
					flagParts,
					"FlagEye",
					Vector3.new(flagX + eye * 0.4, flagY + 0.5, z + face * 0.05),
					Vector3.new(0.45, 0.45, 0.15),
					gear.flag
				)
			end
			for _, bone in { -1, 1 } do
				local part = box(
					flagParts,
					"FlagBone",
					Vector3.new(flagX, flagY - 0.9, poleZ + face * 0.16),
					Vector3.new(3.4, 0.4, 0.15),
					WHITE
				)
				part.CFrame *= CFrame.Angles(0, 0, math.rad(bone * 25))
			end
		end
		for _, part in flagParts do
			joint(rig, part, CFrame.new(at(Vector3.new(0, flagY, poleZ))), Vector3.yAxis, 0.12, 4, 0, false)
		end
	end
	for _, side in { -1, 1 } do
		ticking(
			nil,
			Vector3.new(side * bodyW / 2, bottom + 1.9, (chestFront + 3 + frontEnd) / 2),
			Vector3.xAxis * side,
			Vector3.zAxis,
			Vector2.new(frontEnd - chestFront - 4, 2.6),
			1.25
		)
	end

	-- Cuello que sube desde la cruz y cabeza por delante del pecho, más alta que el lomo.
	local headParts: { BasePart } = {}
	local skull = o.skull
	local head = Vector3.new(0, top + o.neck, chestFront - skull.Z / 2 + 1.4)
	local crown = head.Y + skull.Y / 2
	local skullFront = head.Z - skull.Z / 2
	local neckW = math.min(bodyW - 1.6, skull.X - 0.6)
	local neckZ = chestFront + 1.1
	local neckDepth = 3.4
	box(
		headParts,
		"Neck",
		Vector3.new(0, (top - 0.6 + head.Y) / 2, neckZ),
		Vector3.new(neckW, head.Y - top + 0.6, neckDepth),
		headColor
	)
	-- Garganta del color del pecho, por delante del cuello.
	box(
		headParts,
		"Throat",
		Vector3.new(0, (top - 0.4 + head.Y - 1) / 2, neckZ - neckDepth / 2 + 0.3),
		Vector3.new(neckW - 0.8, head.Y - 1 - top + 0.4, 0.8),
		chest
	)
	-- Cráneo redondeado, en vez de un cubo: la parte de atrás (la bóveda) es ancha, con las aristas en dos escalones, la
	-- nuca achaflanada y una cúpula de dos escalones encima; la de delante (la cara) es algo más estrecha, así la frente
	-- baja hacia el hocico.
	local chamfer = o.skullChamfer or math.clamp(skull.X * 0.26, 1, 1.7)
	local rearLength = skull.Z * 0.62
	local faceLength = skull.Z - rearLength
	local function skullBlock(
		name: string,
		zCenter: number,
		length: number,
		width: number,
		cut: number,
		round: boolean,
		edge: number
	): BasePart
		local half = (width - 2 * edge) / 2
		local core = box(
			headParts,
			name,
			Vector3.new(0, head.Y, zCenter),
			Vector3.new(width - 2 * edge, skull.Y, length),
			headColor
		)
		for _, side in { -1, 1 } do
			box(
				headParts,
				"SkullSide",
				Vector3.new(side * (half + edge * 0.25), head.Y, zCenter),
				Vector3.new(edge * 0.5, skull.Y - cut, length),
				headColor
			)
			if round then
				box(
					headParts,
					"SkullSide",
					Vector3.new(side * (half + edge * 0.75), head.Y, zCenter),
					Vector3.new(edge * 0.5, skull.Y - cut - edge * 1.2, length),
					headColor
				)
			end
		end
		return core
	end
	local backCut = chamfer * 0.8
	local rearCenter = head.Z + skull.Z / 2 - rearLength / 2
	local skullPart =
		skullBlock("Head", rearCenter - backCut / 2, rearLength - backCut, skull.X, chamfer * 0.9, true, chamfer)
	-- Nuca: más estrecha y baja que la bóveda, con las esquinas de atrás cortadas.
	box(
		headParts,
		"Nape",
		Vector3.new(0, head.Y - chamfer * 0.2, head.Z + skull.Z / 2 - backCut / 2),
		Vector3.new(skull.X - 2.6 * chamfer, skull.Y - chamfer * 0.9, backCut),
		headColor
	)
	local faceEdge = o.faceEdge or chamfer
	skullBlock(
		"Face",
		skullFront + faceLength / 2,
		faceLength,
		if o.faceEdge then skull.X - 0.4 else skull.X - chamfer,
		faceEdge * 0.4,
		false,
		faceEdge
	)
	box(
		headParts,
		"Dome",
		Vector3.new(0, crown + 0.25, rearCenter - 0.2),
		Vector3.new(skull.X - 3 * chamfer, 0.5, rearLength - chamfer),
		headColor
	)
	box(
		headParts,
		"Dome",
		Vector3.new(0, crown + 0.7, rearCenter - 0.3),
		Vector3.new(skull.X - 4.4 * chamfer, 0.4, rearLength - 2 * chamfer),
		headColor
	)
	local snout = o.snout
	local muzzleColor = o.muzzle or headColor:Lerp(WHITE, 0.12)
	local snoutCenter = Vector3.new(0, head.Y - skull.Y / 2 + snout.Y / 2 + 0.3, skullFront - snout.Z / 2 + 0.3)
	local snoutTop = snoutCenter.Y + snout.Y / 2
	local snoutBottom = snoutCenter.Y - snout.Y / 2
	local snoutFront = snoutCenter.Z - snout.Z / 2
	box(headParts, "Muzzle", snoutCenter, snout, muzzleColor)
	-- Mandíbula: un poco más estrecha y corta, asoma por debajo (los belfos).
	box(
		headParts,
		"Jaw",
		Vector3.new(0, snoutBottom - 0.35, snoutCenter.Z + 0.4),
		Vector3.new(snout.X - 0.5, 0.8, snout.Z - 0.8),
		muzzleColor:Lerp(BLACK, 0.06)
	)
	box(headParts, "Nose", Vector3.new(0, snoutTop - 0.45, snoutFront - 0.2), Vector3.new(1.8, 1, 0.8), o.nose)
	for _, side in { -1, 1 } do
		flat(
			headParts,
			"Mouth",
			Vector3.new(side * snout.X / 2, snoutBottom + 0.55, snoutCenter.Z - 0.3),
			Vector3.xAxis * side,
			Vector3.zAxis,
			Vector2.new(snout.Z - 1.2, 0.22),
			dark
		)
	end
	if o.tongue then
		box(
			headParts,
			"Tongue",
			Vector3.new(0, snoutBottom - 0.75, snoutFront + 1.1),
			Vector3.new(1.2, 0.9, 1),
			Color3.fromRGB(225, 105, 115)
		)
	end
	if o.blaze then
		-- Lista blanca: sube por la frente desde el hocico y sigue por encima del hocico hasta la trufa.
		flat(
			headParts,
			"Blaze",
			Vector3.new(0, (snoutTop + crown - 0.6) / 2, skullFront),
			-Vector3.zAxis,
			Vector3.xAxis,
			Vector2.new(1.1, crown - 0.6 - snoutTop),
			o.blaze
		)
		flat(
			headParts,
			"Blaze",
			Vector3.new(0, snoutTop, (skullFront + snoutFront + 0.6) / 2),
			Vector3.yAxis,
			Vector3.xAxis,
			Vector2.new(1.1, skullFront - snoutFront - 0.6),
			o.blaze
		)
	end
	-- Ojos en la cara de delante, por encima del hocico: castaño, pupila y un brillo arriba por fuera.
	for _, side in { -1, 1 } do
		local eye = Vector3.new(side * (skull.X / 2 - 1.25), snoutTop + 0.75, skullFront)
		flat(headParts, "Eye", eye, -Vector3.zAxis, Vector3.xAxis, Vector2.new(1.1, 1), o.eye, 0.08)
		flat(headParts, "Pupil", eye, -Vector3.zAxis, Vector3.xAxis, Vector2.new(0.75, 0.8), BLACK, 0.13)
		flat(
			headParts,
			"Glint",
			eye + Vector3.new(side * 0.25, 0.25, 0),
			-Vector3.zAxis,
			Vector3.xAxis,
			Vector2.new(0.28, 0.28),
			WHITE,
			0.18
		)
	end
	if rich then
		-- Pelo de la cabeza, el hocico, las mejillas y el cuello; ojo con párpado y anillo, ceja en relieve, carrillo,
		-- fosas, brillo de la trufa, puntos de los bigotes y la gorguera de la nuca.
		voxelTopScales(
			kit,
			headParts,
			"Strand",
			Vector3.new(0, crown + 1.16, rearCenter - 0.3),
			Vector2.new(skull.X - 4.4 * chamfer - 0.3, rearLength - 2 * chamfer - 0.4),
			Vector2.new(1.0, 1.2),
			tones(headColor),
			0.12
		)
		voxelTopScales(
			kit,
			headParts,
			"Strand",
			Vector3.new(0, crown + 0.56, rearCenter - 0.2),
			Vector2.new(skull.X - 3 * chamfer - 0.4, rearLength - chamfer - 0.4),
			Vector2.new(1.16, 1.45),
			tones(headColor),
			0.12
		)
		voxelTopScales(
			kit,
			headParts,
			"Strand",
			Vector3.new(0, crown + 0.06, skullFront + faceLength / 2),
			Vector2.new(skull.X - 3 * chamfer - 0.4, faceLength - 0.6),
			Vector2.new(1.16, 1.45),
			tones(headColor),
			0.12
		)
		voxelTopScales(
			kit,
			headParts,
			"Strand",
			Vector3.new(0, snoutTop + 0.06, snoutCenter.Z),
			Vector2.new(snout.X - 0.6, snout.Z - 0.8),
			Vector2.new(1.01, 1.16),
			tones(muzzleColor),
			0.12
		)
		for _, side in { -1, 1 } do
			voxelScales(
				kit,
				headParts,
				"Fur",
				"x",
				Vector3.new(side * (skull.X / 2 + 0.05), head.Y, rearCenter),
				Vector2.new(rearLength - 0.8, skull.Y - chamfer * 2.1 - 0.8),
				Vector2.new(1.3, 1.16),
				tones(headColor),
				0.12
			)
			voxelScales(
				kit,
				headParts,
				"Fur",
				"x",
				Vector3.new(side * (snout.X / 2 + 0.05), snoutCenter.Y, snoutCenter.Z),
				Vector2.new(snout.Z - 1, snout.Y - 1),
				Vector2.new(1.01, 1.01),
				tones(muzzleColor),
				0.12
			)
			voxelScales(
				kit,
				headParts,
				"Fur",
				"x",
				Vector3.new(side * (neckW / 2 + 0.05), (top + head.Y) / 2, neckZ),
				Vector2.new(neckDepth - 0.6, head.Y - top - 1),
				Vector2.new(1.3, 1.3),
				tones(headColor),
				0.12
			)
			local eye = Vector3.new(side * (skull.X / 2 - 1.25), snoutTop + 0.75, skullFront)
			flat(
				headParts,
				"EyeRing",
				eye,
				-Vector3.zAxis,
				Vector3.xAxis,
				if o.faceEdge then Vector2.new(1.35, 1.3) else Vector2.new(1.6, 1.5),
				dark,
				0.03
			)
			flat(
				headParts,
				"Lid",
				eye + Vector3.new(0, 0.62, 0),
				-Vector3.zAxis,
				Vector3.xAxis,
				Vector2.new(1.4, 0.3),
				headColor:Lerp(BLACK, 0.4),
				0.2
			)
			if o.iris then
				flat(headParts, "Iris", eye, -Vector3.zAxis, Vector3.xAxis, Vector2.new(0.95, 0.9), o.iris, 0.1)
				flat(headParts, "Pupil", eye, -Vector3.zAxis, Vector3.xAxis, Vector2.new(0.5, 0.55), BLACK, 0.14)
			end
			if o.accent then
				flat(
					headParts,
					"BrowSpot",
					eye + Vector3.new(0, 1.05, 0),
					-Vector3.zAxis,
					Vector3.xAxis,
					Vector2.new(1.1, 0.5),
					o.accent,
					0.06
				)
				flat(
					headParts,
					"CheekSpot",
					Vector3.new(side * (skull.X / 2 + 0.3), head.Y - 0.9, head.Z + 0.2),
					Vector3.xAxis * side,
					Vector3.zAxis,
					Vector2.new(1.8, 1.4),
					o.accent,
					0.05
				)
				flat(
					headParts,
					"MuzzleSpot",
					Vector3.new(side * (snout.X / 2 + 0.06), snoutBottom + 0.95, snoutCenter.Z),
					Vector3.xAxis * side,
					Vector3.zAxis,
					Vector2.new(snout.Z - 1.4, 0.7),
					o.accent,
					0.06
				)
			end
			flat(
				headParts,
				"Glint",
				eye + Vector3.new(-side * 0.22, -0.18, 0),
				-Vector3.zAxis,
				Vector3.xAxis,
				Vector2.new(0.3, 0.3),
				WHITE,
				0.22
			)
			box(
				headParts,
				"Brow",
				Vector3.new(eye.X, snoutTop + 1.65, skullFront + 0.25),
				Vector3.new(1.5, 0.55, 0.7),
				headColor:Lerp(BLACK, 0.08)
			)
			box(
				headParts,
				"Jowl",
				Vector3.new(side * (skull.X / 2 + 0.1), head.Y - skull.Y * 0.2, head.Z + 0.8),
				Vector3.new(0.5, skull.Y * 0.45, skull.Z * 0.5),
				headColor:Lerp(WHITE, 0.06)
			)
			flat(
				headParts,
				"Nostril",
				Vector3.new(side * 0.55, snoutTop - 0.5, snoutFront - 0.6),
				-Vector3.zAxis,
				Vector3.xAxis,
				Vector2.new(0.5, 0.45),
				BLACK,
				0.04
			)
			for k = 0, 2 do
				flat(
					headParts,
					"Whisker",
					Vector3.new(side * snout.X / 2, snoutCenter.Y + 0.4 - k * 0.5, snoutFront + 1.2 + k * 0.3),
					Vector3.xAxis * side,
					Vector3.zAxis,
					Vector2.new(0.22, 0.22),
					dark,
					0.05
				)
			end
		end
		flat(
			headParts,
			"NoseShine",
			Vector3.new(-0.35, snoutTop - 0.12, snoutFront - 0.6),
			-Vector3.zAxis,
			Vector3.xAxis,
			Vector2.new(0.7, 0.2),
			o.nose:Lerp(WHITE, 0.4),
			0.1
		)
		if o.accent then
			-- Barbilla y lista más claras: separan la boca y la frente del resto de la cabeza oscura.
			box(
				headParts,
				"Chin",
				Vector3.new(0, snoutBottom - 0.1, snoutCenter.Z + 0.3),
				Vector3.new(snout.X - 1.2, 0.5, snout.Z - 1.4),
				o.accent:Lerp(WHITE, 0.45)
			)
			flat(
				headParts,
				"BlazeWide",
				Vector3.new(0, (snoutTop + crown - 0.6) / 2 + 0.3, skullFront),
				-Vector3.zAxis,
				Vector3.xAxis,
				Vector2.new(1.6, crown - 1.2 - snoutTop),
				WHITE,
				0.07
			)
		end
		box(
			headParts,
			"Ruff",
			Vector3.new(0, (top + head.Y) / 2 - 0.6, neckZ + neckDepth / 2 + 0.2),
			Vector3.new(neckW + 0.6, head.Y - top - 1.4, 0.6),
			headColor:Lerp(coat, 0.5)
		)
	end
	if o.collar then
		local collarY = top + (head.Y - skull.Y / 2 - top) * 0.35
		box(
			headParts,
			"Collar",
			Vector3.new(0, collarY, neckZ),
			Vector3.new(neckW + 0.4, 0.9, neckDepth + 0.4),
			o.collar
		)
		box(
			headParts,
			"CollarTag",
			Vector3.new(0, collarY - 0.75, neckZ - neckDepth / 2 - 0.3),
			Vector3.new(0.7, 0.8, 0.3),
			Color3.fromRGB(235, 190, 60)
		)
	end
	-- El pañuelo de la skin, con lunares y el nudo detrás ("bandana"), y el parche del ojo izquierdo con
	-- su cinta ("eyePatch").
	if gear.bandana then
		box(
			headParts,
			"Bandana",
			Vector3.new(0, crown + 0.2, head.Z + 0.3),
			Vector3.new(skull.X + 0.3, 0.6, skull.Z),
			gear.bandana
		)
		box(
			headParts,
			"Bandana",
			Vector3.new(0, crown - 0.35, head.Z + 0.3),
			Vector3.new(skull.X + 0.35, 0.7, skull.Z + 0.2),
			gear.bandana
		)
		for _, dot in { -1.2, 0.3, 1.5 } do
			box(
				headParts,
				"BandanaDot",
				Vector3.new(dot, crown + 0.52, head.Z + dot * 0.5),
				Vector3.new(0.5, 0.1, 0.5),
				WHITE
			)
		end
		local back = head.Z + skull.Z / 2 + 0.4
		box(headParts, "BandanaKnot", Vector3.new(0, crown - 0.3, back), Vector3.new(1.1, 0.9, 0.8), gear.bandana)
		for _, side in { -1, 1 } do
			local ribbon = box(
				headParts,
				"BandanaTail",
				Vector3.new(side * 0.45, crown - 1.2, back + 0.35),
				Vector3.new(0.6, 1.5, 0.25),
				gear.bandana
			)
			ribbon.CFrame *= CFrame.Angles(math.rad(20), 0, math.rad(side * 18))
		end
	end
	if gear.eyePatch then
		local eye = Vector3.new(-(skull.X / 2 - 1.25), snoutTop + 0.75, skullFront)
		flat(headParts, "EyePatch", eye, -Vector3.zAxis, Vector3.xAxis, Vector2.new(1.6, 1.4), gear.eyePatch, 0.2)
		-- La cinta cruza la frente en diagonal, del parche a la sien de enfrente.
		local from, to = eye + Vector3.new(0.4, 0.5, 0), Vector3.new(skull.X / 2, crown - 0.5, skullFront)
		local direction = to - from
		flat(
			headParts,
			"EyePatchStrap",
			(from + to) / 2,
			-Vector3.zAxis,
			Vector3.new(direction.X, direction.Y, 0).Unit,
			Vector2.new(direction.Magnitude, 0.3),
			gear.eyePatch,
			0.17
		)
	end
	-- La cabeza (con cuello, collar y cara) mira despacio a un lado y a otro, girando sobre la nuca.
	local neckHinge = CFrame.new(at(Vector3.new(0, top - 0.6, neckZ)))
	local skullJoint: Joint? = nil
	for _, part in headParts do
		local item = joint(rig, part, neckHinge, Vector3.yAxis, 0.2, 0.9, 0, false)
		item.bone = "Head"
		item.bend = 0.5
		if part == skullPart then
			skullJoint = item
		end
	end
	-- Orejas caídas a los lados del cráneo, colgando desde arriba: van con la cabeza y aletean un poco
	-- al andar.
	local ear = o.ear
	for _, side in { -1, 1 } do
		local x = side * (skull.X / 2 + ear.X / 2 - 0.05)
		local earTop = crown - 0.35
		local earZ = head.Z + skull.Z / 2 - ear.Z / 2 - 0.5
		local parts = { box(nil, "Ear", Vector3.new(x, earTop - ear.Y / 2, earZ), ear, o.ears or headColor) }
		-- El aro de oro de la skin ("earring"), abajo en la oreja derecha.
		if gear.earring and side > 0 then
			table.insert(
				parts,
				box(
					nil,
					"Earring",
					Vector3.new(x, earTop - ear.Y - 0.3, earZ - ear.Z / 2 + 0.5),
					Vector3.new(0.3, 0.9, 0.9),
					gear.earring
				)
			)
		end
		for _, part in parts do
			local item = joint(
				rig,
				part,
				CFrame.new(at(Vector3.new(x, earTop, earZ))),
				Vector3.zAxis,
				0.08 * side,
				9,
				0,
				true,
				nil,
				skullJoint
			)
			item.bone = if side < 0 then "EarL" else "EarR"
		end
	end

	-- Patas de dos tramos. Delante, hombro (algo más claro, asoma por el costado) y columna recta;
	-- detrás, anca y muslo más oscuro que abulta por detrás, y el tramo de abajo retrasado: el corvejón.
	local knee = legH * 0.5
	local hipY = centerY
	local phases = { 0, math.pi, math.pi, 0 }
	local bones = { "FL", "FR", "BL", "BR" }
	local zFront, zBack = chestFront + 2.6, bodyL / 2 - 2.4
	local paw = legColor:Lerp(WHITE, 0.08)
	for i, spot in { { -1, true }, { 1, true }, { -1, false }, { 1, false } } do
		local side: number, isFront: boolean = spot[1], spot[2]
		local width = if isFront then o.legW else o.legW + 0.2
		local x = side * (bodyW / 2 - 1.2)
		local z = if isFront then zFront else zBack
		local outward = Vector3.xAxis * side
		local upper: { BasePart } = {}
		local lower: { BasePart } = {}
		local upperTop = bottom + 1
		local lowZ = z
		if isFront then
			-- Con la camiseta de la skin, la camiseta hace de hombro y el brazo sale de ella por un puño
			-- azul. El hombro gira con la pata: dentro de la camiseta fija se salía en diagonal al galopar.
			if gear.shirt and gear.shirtStripe then
				box(
					upper,
					"SleeveCuff",
					Vector3.new(x, bottom, z),
					Vector3.new(width + 0.6, 1.2, width + 0.6),
					gear.shirtStripe
				)
			else
				box(
					upper,
					"Shoulder",
					Vector3.new(side * (bodyW / 2 - 0.85), bottom + bodyH * 0.42, z - 0.2),
					Vector3.new(2, bodyH * 0.66, 3.4),
					shoulderColor
				)
			end
			box(
				upper,
				"UpperArm",
				Vector3.new(x, (knee + upperTop) / 2, z),
				Vector3.new(width + 0.2, upperTop - knee, width + 0.2),
				coat
			)
		else
			box(
				upper,
				"Haunch",
				Vector3.new(side * (bodyW / 2 - 1), (hipBottom - 0.3 + top - 0.4) / 2, z + 0.2),
				Vector3.new(2.4, top - hipBottom - 0.1, 4.4),
				coat
			)
			box(
				upper,
				"Thigh",
				Vector3.new(x, (knee + upperTop) / 2, z - 0.2),
				Vector3.new(width + 0.4, upperTop - knee, width + 1.2),
				muscle
			)
			lowZ = z + 0.9
		end
		local shin = width - 0.4
		box(
			lower,
			if isFront then "Forearm" else "Shin",
			Vector3.new(x, (knee + 0.3 + 1.1) / 2, lowZ),
			Vector3.new(shin, knee + 0.3 - 1.1, shin),
			legColor
		)
		ticking(
			upper,
			Vector3.new(x, (knee + bottom) / 2, z) + outward * (width + 0.3) / 2,
			outward,
			Vector3.zAxis,
			Vector2.new(width, bottom - knee - 0.6),
			1.1
		)
		ticking(
			lower,
			Vector3.new(x, knee / 2 + 0.6, lowZ) + outward * shin / 2,
			outward,
			Vector3.zAxis,
			Vector2.new(shin - 0.3, knee - 1.6),
			1.1
		)
		local pawCenter = Vector3.new(x, 0.6, lowZ - 0.6)
		local pawSize = Vector3.new(width + 0.3, 1.2, 2.8)
		box(lower, "Paw", pawCenter, pawSize, paw)
		for _, toe in { -1, 1 } do
			box(
				lower,
				"Toe",
				pawCenter + Vector3.new(toe * pawSize.X / 6, 0.15, -pawSize.Z / 2 + 0.55),
				Vector3.new(0.2, pawSize.Y - 0.2, 1.2),
				paw:Lerp(BLACK, 0.5)
			)
		end
		if rich then
			-- Uñas, y el pelo pintado de los dos tramos de la pata.
			for k = -1, 1 do
				box(
					lower,
					"Claw",
					Vector3.new(x + k * (width + 0.3) / 3, 0.4, lowZ - 0.6 - pawSize.Z / 2 - 0.06),
					Vector3.new(0.5, 0.55, 0.12),
					paw:Lerp(BLACK, 0.55)
				)
			end
			local upperW = if isFront then width + 0.2 else width + 0.4
			voxelScales(
				kit,
				upper,
				"Fur",
				"x",
				Vector3.new(x + side * (upperW / 2 + 0.05), (knee + upperTop) / 2, z),
				Vector2.new(upperW, upperTop - knee - 0.6),
				Vector2.new(1.16, 1.3),
				tones(coat),
				0.12
			)
			voxelScales(
				kit,
				lower,
				"Fur",
				"x",
				Vector3.new(x + side * (shin / 2 + 0.05), (knee + 1.4) / 2 + 0.2, lowZ),
				Vector2.new(shin - 0.2, knee - 1.4),
				Vector2.new(1.16, 1.3),
				tones(legColor),
				0.12
			)
			voxelScales(
				kit,
				lower,
				"Fur",
				"z",
				Vector3.new(x, (knee + 1.4) / 2 + 0.2, lowZ - shin / 2 - 0.05),
				Vector2.new(shin - 0.2, knee - 1.4),
				Vector2.new(1.01, 1.3),
				tones(legColor),
				0.12
			)
		end
		local thigh: Joint? = nil
		for _, part in upper do
			thigh = joint(
				rig,
				part,
				CFrame.new(at(Vector3.new(x, hipY, z))),
				Vector3.xAxis,
				0.45,
				9,
				phases[i],
				true,
				nil,
				if isFront then nil else spine
			)
			thigh.bone = bones[i]
		end
		for _, part in lower do
			local item = joint(
				rig,
				part,
				CFrame.new(at(Vector3.new(x, knee, z))),
				Vector3.xAxis,
				-0.3,
				9,
				phases[i] + math.pi / 2,
				true,
				-0.3,
				thigh
			)
			item.bone = bones[i] .. "2"
		end
	end

	-- Cola por tramos desde la grupa; menea de lado a lado girando sobre el eje perpendicular a su
	-- primer tramo (así también menea la cola alta del beagle, que con el eje vertical solo giraría).
	local from = Vector3.new(0, top - 0.7, bodyL / 2 - 0.3)
	local tailBase = from
	local tailRises: { number } = {}
	for i, heading in o.tail do
		tailRises[i] = math.asin(heading.Unit.Y)
	end
	local wag = o.tail[1].Unit:Cross(Vector3.xAxis).Unit
	local tailWidth = o.tailWidth
	local previous: Joint? = spine
	for i, heading in o.tail do
		local direction = heading.Unit
		local to = from + direction * o.tailSegment
		local frame = CFrame.lookAt(at((from + to) / 2), at(to))
		local last = i == #o.tail
		local parts = {
			piece(
				rig,
				"Tail",
				"Block",
				Vector3.new(tailWidth, tailWidth, o.tailSegment + 0.5) * VOXEL,
				frame,
				o.tailColor or coat,
				material
			),
		}
		if last and o.tailTip then
			local tip = frame * CFrame.new(0, 0, -(o.tailSegment / 2) * VOXEL)
			table.insert(
				parts,
				piece(
					rig,
					"TailTip",
					"Block",
					Vector3.new(tailWidth + 0.1, tailWidth + 0.1, 1.8) * VOXEL,
					tip,
					o.tailTip,
					material
				)
			)
		end
		local link: Joint? = nil
		for _, part in parts do
			local item = joint(rig, part, CFrame.new(at(from)), wag, 0.18, 6, -(i - 1) * 0.55, false, nil, previous)
			item.bone = "Tail"
			item.lag = i - 1
			link = item
		end
		previous = link
		from = to
		tailWidth = math.max(0.8, tailWidth - o.tailTaper)
	end

	rig.family = "Dog"
	rig.dims = {
		length = bodyL * VOXEL,
		legHeight = legH * VOXEL,
		bodyY = 0,
		ground = at(Vector3.zero).Y,
		hips = at(Vector3.new(0, hipY, zBack)),
		shoulders = at(Vector3.new(0, hipY, zFront)),
		center = Vector3.zero,
		haunch = at(Vector3.new(0, hipBottom - 0.3, 0)).Y,
		-- Para sentarse: la esquina de abajo y atrás de la grupa (la que toca el suelo) y la rodilla.
		rump = at(Vector3.new(0, hipBottom - 0.3, bodyL / 2)),
		knee = at(Vector3.new(0, knee, 0)).Y,
		-- Del centro del cuerpo a la quilla (para tumbarse sin hundirse) y al costado, con las alforjas
		-- si las lleva (para ponerse de lado).
		halfHeight = (bodyH / 2 + 1.1) * VOXEL,
		halfWidth = (bodyW / 2 + (if o.pack then 1.3 else 0.3)) * VOXEL,
		-- La cola: dónde nace, cuánto sube cada tramo (radianes sobre la horizontal) y su largo.
		tail = { base = at(tailBase), rises = tailRises, segment = o.tailSegment * VOXEL },
	}
end

local builders: { [string]: (rig: Rig, color: Color3) -> Motion } = {
	-- Jaguarundí: felino esbelto, liso y oscuro.
	Jaguarundi = function(rig, color)
		felid(rig, color, { eyeColor = Color3.fromRGB(200, 170, 40), earSize = 0.24, roundEars = true, slim = true })
		return "Walk"
	end,

	-- Ocelote: felino dorado con manchas negras.
	Ocelote = function(rig, color)
		felid(rig, color, { spots = BLACK, eyeColor = Color3.fromRGB(120, 200, 60), earSize = 0.38 })
		return "Walk"
	end,

	-- Beagle (docs/img/beagle-*.webp): compacto y de patas cortas, tricolor (canela, manto negro en el
	-- lomo y blanco en el hocico, la lista, el pecho y las patas), orejas largas caídas y la cola alta
	-- en bandera, negra con la punta blanca: lo que más se ve de espaldas.
	Beagle = function(rig, color)
		local white = Color3.fromRGB(240, 236, 228)
		local black = Color3.fromRGB(32, 28, 28)
		voxelDog(rig, color, {
			legH = 5.5,
			legW = 2.1,
			bodyH = 6,
			bodyW = 5.6,
			bodyL = 15,
			tuck = 0.8,
			skull = Vector3.new(5.2, 4.8, 4.8),
			snout = Vector3.new(3, 2.6, 3.2),
			neck = 3.4,
			ear = Vector3.new(0.8, 5.2, 2.6),
			tail = { Vector3.new(0, 1.4, 1), Vector3.new(0, 3, 0.7), Vector3.new(0, 3, 0) },
			tailSegment = 2.4,
			tailWidth = 1.5,
			tailTaper = 0.1,
			eye = Color3.fromRGB(70, 40, 20),
			nose = BLACK,
			saddle = black,
			ears = color:Lerp(BLACK, 0.18),
			muzzle = white,
			blaze = white,
			chest = white,
			legs = white,
			tailColor = black,
			tailTip = white,
			collar = Color3.fromRGB(200, 35, 35),
		})
		return "Walk"
	end,

	-- Labrador (docs/img/*labrador*.webp): robusto y ancho, amarillo claro con el pecho más pálido,
	-- cabeza ancha de hocico corto y fuerte, orejas medianas caídas, la lengua fuera y la cola de
	-- nutria (gruesa en la base y fina en la punta), recta hacia atrás.
	Labrador = function(rig, color)
		voxelDog(rig, color, {
			legH = 6.5,
			legW = 2.6,
			bodyH = 7,
			bodyW = 7,
			bodyL = 17,
			tuck = 0.6,
			skull = Vector3.new(6.2, 5.4, 5.4),
			faceEdge = 0.7,
			skullChamfer = 1.3,
			snout = Vector3.new(3.8, 2.8, 3.2),
			neck = 3.6,
			ear = Vector3.new(0.8, 3.2, 2.6),
			-- Cola de nutria: unos 2/3 del cuerpo, gruesa en la base y adelgazando poco a poco (más fina
			-- parecía una cuerda; más corta, un muñón).
			tail = {
				Vector3.new(0, 0.25, 1),
				Vector3.new(0, 0.08, 1),
				Vector3.new(0, -0.02, 1),
				Vector3.new(0, 0.05, 1),
			},
			tailSegment = 2.6,
			tailWidth = 2.4,
			tailTaper = 0.35,
			eye = Color3.fromRGB(80, 50, 25),
			nose = Color3.fromRGB(85, 55, 45),
			ears = color:Lerp(Color3.fromRGB(150, 95, 45), 0.25),
			chest = color:Lerp(WHITE, 0.12),
			collar = Color3.fromRGB(40, 40, 45),
			tongue = true,
			pack = Color3.fromRGB(60, 110, 60),
		})
		return "Walk"
	end,

	-- Pointer inglés (docs/img/pointer*.webp): esbelto, de patas largas, pecho hondo y cintura muy
	-- recogida, blanco con la cabeza y las orejas negras y una lista blanca, manchas negras en el lomo
	-- y la grupa, moteado fino y la cola en línea con el lomo.
	Pointer = function(rig, color)
		local black = Color3.fromRGB(35, 30, 30)
		voxelDog(rig, color, {
			legH = 8,
			legW = 1.8,
			bodyH = 5.6,
			bodyW = 5,
			bodyL = 17,
			tuck = 1.4,
			skull = Vector3.new(3.9, 3.9, 4.2),
			snout = Vector3.new(2.5, 2.2, 4.4),
			neck = 4.6,
			ear = Vector3.new(0.6, 3.3, 1.8),
			tail = { Vector3.new(0, 0.25, 1), Vector3.new(0, 0.1, 1), Vector3.new(0, 0.05, 1) },
			tailSegment = 2.6,
			tailWidth = 1.5,
			tailTaper = 0.3,
			-- Casi negro: un iris castaño sobre la cabeza negra, con la lista entre los ojos, parecía unas gafas.
			eye = Color3.fromRGB(48, 32, 22),
			nose = Color3.fromRGB(22, 18, 18),
			head = black,
			ears = black,
			muzzle = Color3.fromRGB(78, 64, 58),
			accent = Color3.fromRGB(165, 115, 70),
			iris = Color3.fromRGB(205, 135, 45),
			blaze = color,
			chest = color,
			legs = color,
			patches = function(top)
				return {
					-- Mancha grande del lomo, de la cruz a la cintura, que baja por los costados.
					{ center = Vector3.new(0, top - 1.4, -2.2), size = Vector3.new(5.12, 2.9, 6.4) },
					-- La de la grupa, alrededor de la base de la cola (se ve de espaldas).
					{ center = Vector3.new(0, top - 1.5, 6.4), size = Vector3.new(4.72, 3.1, 4.4), hips = true },
				}
			end,
			patchColor = black,
			ticking = black,
			collar = Color3.fromRGB(95, 60, 35),
		})
		return "Walk"
	end,

	-- Jaguar de cristal: felino de hielo cristalino con manchas que brillan por dentro, racimos de
	-- cristales en el lomo y los hombros, un cristal en la frente y un corazón que late de luz.
	-- Con una skin, sus cristales cambian de color ("crystal" y "crystalGlow" en la paleta).
	JaguarCristal = function(rig, color)
		local glow = Color3.fromRGB(80, 200, 255)
		local options: CatOptions = {
			spots = glow,
			crystal = true,
			eyeColor = Color3.fromRGB(120, 235, 255),
			earSize = 0.36,
		}
		felid(rig, color, options)
		color = tone(rig, "crystal", color)
		glow = tone(rig, "crystalGlow", glow)
		if PetModels.voxelCats then
			voxelCrystals(rig, color, glow)
		else
			-- Cada cristal es una pirámide alargada de vidrio con un núcleo que brilla dentro: se ve en
			-- punta desde cualquier lado. "from" es donde nace y "direction" hacia dónde crece.
			local function crystal(from: Vector3, direction: Vector3, length: number, width: number): { BasePart }
				local unit = direction.Unit
				local center = from + unit * (length / 2 - 0.06)
				local frame = CFrame.lookAt(center, center + unit) * CFrame.Angles(-math.pi / 2, 0, 0)
				local shell =
					piece(rig, "Crystal", "Spike", Vector3.new(width, length, width), frame, color, Enum.Material.Glass)
				shell.Transparency = 0.3
				local core = piece(
					rig,
					"CrystalCore",
					"Spike",
					Vector3.new(width * 0.45, length * 0.7, width * 0.45),
					frame * CFrame.new(-width * 0.12, -length * 0.1, width * 0.12),
					glow,
					Enum.Material.Neon
				)
				return { shell, core }
			end
			-- Racimos del lomo (de delante atrás, cada vez más bajos) y de los hombros.
			crystal(Vector3.new(0.05, 0.38, -0.5), Vector3.new(0.1, 1, -0.15), 0.62, 0.24)
			crystal(Vector3.new(-0.1, 0.36, -0.42), Vector3.new(-0.5, 1, 0.1), 0.42, 0.18)
			crystal(Vector3.new(0, 0.4, -0.05), Vector3.new(0.2, 1, 0.25), 0.55, 0.22)
			crystal(Vector3.new(-0.08, 0.38, 0.05), Vector3.new(-0.45, 1, 0.3), 0.36, 0.16)
			crystal(Vector3.new(0.02, 0.37, 0.4), Vector3.new(0.05, 1, 0.4), 0.44, 0.2)
			crystal(Vector3.new(0.05, 0.34, 0.72), Vector3.new(0.35, 1, 0.5), 0.3, 0.15)
			for _, side in { -1, 1 } do
				crystal(Vector3.new(side * 0.42, 0.2, -0.68), Vector3.new(side, 0.9, -0.2), 0.38, 0.17)
				crystal(Vector3.new(side * 0.44, 0.08, -0.58), Vector3.new(side, 0.4, 0.2), 0.26, 0.13)
			end
			-- Cristal en la frente: gira con la cabeza (lo recoge el cuello del felino al final).
			local brow = crystal(Vector3.new(0, 0.86, -1.42), Vector3.new(0, 1, -0.55), 0.3, 0.14)
			for _, part in brow do
				joint(rig, part, CFrame.new(0, 0.4, -0.9), Vector3.yAxis, 0.25, 0.9, 0, false).bone = "Head"
			end
		end
		-- Corazón de luz en el pecho, que se ve a través del cristal.
		local heart =
			piece(rig, "Heart", "Ball", Vector3.one * 0.3, CFrame.new(0, 0.05, -0.65), glow, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = if rig.palette then glow else color
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = heart
		-- Con una skin no: sus chispas las pone la skin.
		local body = rig.model:FindFirstChild("Body")
		if body and not rig.palette then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = color
			sparkles.Parent = body
		end
		return "Walk"
	end,
}

-- ===== Mascotas voxel (aves y rana) =====

-- Celda de las mascotas voxel que no son felinos, en studs a escala 1. El alto final sale de "size"
-- en Data.Pets (GDD §8.2, "Tamaño real con mínimo").
local CELL = 0.1

type VoxelKit = {
	-- Celdas (suelo en y = 0) a coordenadas del modelo (sin escalar).
	at: (cell: Vector3) -> Vector3,
	box: (list: { BasePart }?, name: string, center: Vector3, size: Vector3, color: Color3) -> BasePart,
	-- Bloque de "from" a "to" con sección "width" (colas, plumas): su largo sigue la línea.
	beam: (list: { BasePart }?, name: string, from: Vector3, to: Vector3, width: Vector2, color: Color3) -> BasePart,
	-- Articula todas las piezas con la misma bisagra (en celdas), como una sola.
	swing: (
		parts: { BasePart },
		hinge: Vector3,
		axis: Vector3,
		amplitude: number,
		speed: number,
		phase: number,
		gait: boolean,
		bias: number?,
		bone: string?
	) -> (),
}

-- Ayudas para colocar bloques en celdas alrededor de "origin" (la celda que queda en el pivote).
local function voxelKit(rig: Rig, origin: Vector3): VoxelKit
	local function at(cell: Vector3): Vector3
		return (cell - origin) * CELL
	end
	local function add(list: { BasePart }?, part: BasePart): BasePart
		if list then
			table.insert(list, part)
		end
		return part
	end
	return {
		at = at,
		box = function(list, name, center, size, color)
			return add(list, piece(rig, name, "Block", size * CELL, CFrame.new(at(center)), color))
		end,
		beam = function(list, name, from, to, width, color)
			local direction = to - from
			local up = if math.abs(direction.Unit.Y) > 0.95 then Vector3.zAxis else Vector3.yAxis
			local size = Vector3.new(width.X, width.Y, direction.Magnitude) * CELL
			return add(list, piece(rig, name, "Block", size, CFrame.lookAt(at((from + to) / 2), at(to), up), color))
		end,
		swing = function(parts, hinge, axis, amplitude, speed, phase, gait, bias, bone)
			for _, part in parts do
				joint(rig, part, CFrame.new(at(hinge)), axis, amplitude, speed, phase, gait, bias).bone = bone
			end
		end,
	}
end

-- Ala voxel abierta hacia el lado "side", en escalones que se estrechan hacia la punta, con las
-- remeras en el borde de atrás. "steps" son las cajas del ala derecha relativas a la bisagra.
type WingBlock = { center: Vector3, size: Vector3, color: Color3 }

local function voxelWing(
	v: VoxelKit,
	side: number,
	hinge: Vector3,
	steps: { WingBlock },
	amplitude: number,
	speed: number
)
	local parts: { BasePart } = {}
	for _, step in steps do
		local center = hinge + Vector3.new(step.center.X * side, step.center.Y, step.center.Z)
		v.box(parts, "Wing", center, step.size, step.color)
	end
	v.swing(parts, hinge, Vector3.zAxis, amplitude * side, speed, 0, false, nil, if side < 0 then "WingL" else "WingR")
end

local voxelBuilders: { [string]: (rig: Rig, color: Color3) -> Motion } = {
	-- Tucán voxel (docs/img/Tucan.jfif): erguido y negro, babero crema con el borde amarillo, cara
	-- amarilla con el ojo en un cuadro rojo, pico enorme naranja con una franja oscura y la punta roja
	-- ganchuda, patas grises y cola cuadrada que cae. Vuela, así que lleva las alas abiertas en
	-- escalones (en la foto están plegadas).
	Tucan = function(rig, color)
		local v = voxelKit(rig, Vector3.new(0, 11, 0))
		local box = v.box
		local cream = Color3.fromRGB(245, 235, 165)
		local yellow = Color3.fromRGB(250, 200, 35)
		local orange = Color3.fromRGB(255, 135, 20)
		local deep = Color3.fromRGB(225, 75, 20)
		local red = Color3.fromRGB(205, 40, 30)
		local feet = Color3.fromRGB(80, 80, 88)
		-- Negro algo azulado para las remeras y el borde del ala: separa las capas sin otro color.
		local sheen = color:Lerp(Color3.fromRGB(80, 85, 110), 0.4)
		local gloss = color:Lerp(Color3.fromRGB(120, 130, 170), 0.5) -- brillo azulado de una pluma
		local creamDark = cream:Lerp(Color3.fromRGB(205, 175, 100), 0.5)

		-- Patas cortas con dos dedos delante (con una rendija entre ellos), uno detrás y uñas.
		for _, side in { -1, 1 } do
			local x = side * 1.6
			box(nil, "Leg", Vector3.new(x, 2.4, 0.6), Vector3.new(1.2, 2.8, 1.2), feet)
			box(nil, "Scale", Vector3.new(x, 2.9, -0.05), Vector3.new(1.0, 0.3, 0.1), feet:Lerp(BLACK, 0.4))
			box(nil, "Scale", Vector3.new(x, 2.1, -0.05), Vector3.new(1.0, 0.3, 0.1), feet:Lerp(BLACK, 0.4))
			box(nil, "Toe", Vector3.new(x, 0.4, -0.4), Vector3.new(1.8, 0.8, 2.6), feet)
			box(nil, "ToeGap", Vector3.new(x, 0.45, -1.2), Vector3.new(0.2, 0.75, 1.1), feet:Lerp(BLACK, 0.5))
			box(nil, "Toe", Vector3.new(x, 0.4, 1.7), Vector3.new(0.9, 0.8, 1.4), feet)
			box(nil, "Claw", Vector3.new(x, 0.3, -2.0), Vector3.new(0.9, 0.5, 0.5), BLACK)
			box(nil, "Claw", Vector3.new(x, 0.3, 2.6), Vector3.new(0.7, 0.5, 0.5), BLACK)
			-- Muslo emplumado: se ensancha sobre la pata y asoma por los costados.
			box(nil, "Thigh", Vector3.new(side * 3.45, 6.8, 0.6), Vector3.new(0.7, 3.2, 3.4), color:Lerp(sheen, 0.25))
		end

		-- Cuerpo en tres bloques que se estrechan hacia el cuello.
		-- Barriga: empieza delgada sobre las patas y engrosa en cuatro escalones hasta el pecho, con plumas pintadas.
		box(nil, "Belly", Vector3.new(0, 4.7, 0.6), Vector3.new(5, 1.4, 5.6), color)
		box(nil, "Belly", Vector3.new(0, 6.1, 0.7), Vector3.new(6.2, 1.4, 6.6), color)
		box(nil, "Belly", Vector3.new(0, 7.5, 0.8), Vector3.new(7.4, 1.4, 7.6), color)
		box(nil, "Belly", Vector3.new(0, 8.6, 0.5), Vector3.new(8, 0.8, 8.6), color)
		for row, spec in { { 4.7, -2.15, 5 }, { 6.1, -2.6, 6.2 }, { 7.5, -3.0, 7.4 } } do
			for col = -1, 1 do
				box(
					nil,
					"BellyFeather",
					Vector3.new(col * spec[3] / 3.6 + (row % 2) * 0.4, spec[1], spec[2] - 0.1),
					Vector3.new(spec[3] / 3.6 - 0.2, 0.35, 0.2),
					if (row + col) % 2 == 0 then gloss else sheen
				)
			end
		end
		box(nil, "Body", Vector3.new(0, 11.5, 0), Vector3.new(7.8, 5, 7.4), color)
		box(nil, "Shoulders", Vector3.new(0, 15.5, 0), Vector3.new(7, 3, 7.4), color)
		-- Manto azulado en la espalda, en dos escalones: sin él, de espaldas era una losa negra. Encima, filas
		-- de plumas pintadas (el borde de cada pluma más claro) y la franja roja de debajo de la cola.
		box(nil, "Mantle", Vector3.new(0, 13.4, 3.85), Vector3.new(5.6, 5.4, 0.4), color:Lerp(sheen, 0.5))
		box(nil, "Mantle", Vector3.new(0, 11.4, 4.1), Vector3.new(4.4, 3, 0.4), sheen)
		for row = 0, 5 do
			for col = -2, 2 do
				local offset = if row % 2 == 0 then 0 else 0.55
				local x = col * 1.05 + offset
				if math.abs(x) < 2.6 then
					box(
						nil,
						"BackFeather",
						Vector3.new(x, 15.4 - row * 1.0, 4.35),
						Vector3.new(0.85, 0.35, 0.2),
						if (row + col) % 2 == 0 then gloss else sheen
					)
				end
			end
		end
		box(nil, "Vent", Vector3.new(0, 7.4, 4.75), Vector3.new(6.6, 1.4, 0.25), red)
		box(nil, "VentEdge", Vector3.new(0, 8.3, 4.95), Vector3.new(6.6, 0.4, 0.25), deep)
		-- Babero crema por delante y por los lados del pecho, con el borde de abajo amarillo y las plumas pintadas.
		box(nil, "Bib", Vector3.new(0, 13, -3.85), Vector3.new(6.2, 6.5, 0.5), cream)
		box(nil, "BibEdge", Vector3.new(0, 9.4, -3.9), Vector3.new(6.4, 1.2, 0.6), yellow)
		for row = 0, 5 do
			for col = -2, 2 do
				local offset = if row % 2 == 0 then 0 else 0.55
				local x = col * 1.15 + offset
				if math.abs(x) < 2.9 then
					box(
						nil,
						"BibFeather",
						Vector3.new(x, 15.7 - row * 1.0, -4.2),
						Vector3.new(0.95, 0.4, 0.2),
						if (row + col) % 2 == 0 then creamDark else cream:Lerp(WHITE, 0.5)
					)
				end
			end
		end
		for _, side in { -1, 1 } do
			box(nil, "BibSide", Vector3.new(side * 3.95, 11.8, -2.4), Vector3.new(0.2, 4.4, 2.8), cream)
			box(nil, "BibSide", Vector3.new(side * 4.1, 12.4, -2.4), Vector3.new(0.1, 0.3, 2.4), creamDark)
			box(nil, "BibSide", Vector3.new(side * 4.1, 11.0, -2.4), Vector3.new(0.1, 0.3, 2.4), creamDark)
		end

		-- Cabeza: bloque negro con la garganta crema, mejillas amarillas y el ojo en su cuadro rojo con párpados.
		local head: { BasePart } = {}
		box(head, "Head", Vector3.new(0, 19, -1), Vector3.new(6.4, 6, 6.4), color)
		box(head, "Crown", Vector3.new(0, 22.4, -0.6), Vector3.new(5.4, 0.8, 5), color)
		box(head, "Crown", Vector3.new(0, 23, 0.2), Vector3.new(3.8, 0.5, 3.2), sheen)
		box(head, "Nape", Vector3.new(0, 19.4, 2.35), Vector3.new(5.2, 4.4, 0.6), color:Lerp(sheen, 0.4))
		for i, x in { -1.8, -0.6, 0.6, 1.8 } do
			box(head, "CrownFeather", Vector3.new(x, 23.35, -0.4 + (i % 2) * 1.2), Vector3.new(0.7, 0.2, 1.6), gloss)
		end
		box(head, "Throat", Vector3.new(0, 16.6, -4.35), Vector3.new(5.4, 1.8, 0.5), cream)
		for _, side in { -1, 1 } do
			box(head, "Cheek", Vector3.new(side * 3.25, 17.8, -2.6), Vector3.new(0.3, 2.6, 3.2), yellow)
			box(
				head,
				"CheekFeather",
				Vector3.new(side * 3.45, 17.3, -2.4),
				Vector3.new(0.1, 0.4, 2.4),
				yellow:Lerp(WHITE, 0.3)
			)
			box(head, "EyeSkin", Vector3.new(side * 3.3, 20, -2.4), Vector3.new(0.3, 2.4, 2.6), red)
			box(head, "EyeRing", Vector3.new(side * 3.45, 20, -2.45), Vector3.new(0.1, 2, 2.2), deep)
			box(
				head,
				"Iris",
				Vector3.new(side * 3.52, 20, -2.5),
				Vector3.new(0.1, 1.5, 1.5),
				Color3.fromRGB(115, 70, 30)
			)
			box(head, "Eye", Vector3.new(side * 3.58, 20, -2.5), Vector3.new(0.1, 1, 1), Color3.fromRGB(25, 30, 45))
			box(head, "Glint", Vector3.new(side * 3.66, 20.25, -2.75), Vector3.new(0.1, 0.35, 0.35), WHITE)
			box(head, "Lid", Vector3.new(side * 3.58, 20.85, -2.5), Vector3.new(0.1, 0.3, 1.6), color)
		end
		-- Pico: base amarilla, mandíbula de arriba naranja con la franja oscura y la cresta en escalón,
		-- la de abajo más rojiza, la comisura oscura entre las dos con los dientes de sierra, y la punta roja
		-- que baja en gancho.
		box(head, "BeakBase", Vector3.new(0, 19, -4.7), Vector3.new(4.6, 4.8, 1.2), yellow)
		box(head, "Beak", Vector3.new(0, 19.6, -9.8), Vector3.new(4.2, 3.2, 9.6), orange)
		box(head, "BeakRidge", Vector3.new(0, 21.4, -8.4), Vector3.new(3.4, 0.6, 6.4), Color3.fromRGB(255, 170, 40))
		box(head, "BeakRidge", Vector3.new(0, 21.85, -7.6), Vector3.new(2.4, 0.4, 3.6), Color3.fromRGB(255, 195, 70))
		box(head, "BeakStripe", Vector3.new(0, 19.6, -11), Vector3.new(4.35, 1.2, 5.4), deep)
		box(head, "LowerBeak", Vector3.new(0, 17.2, -9.2), Vector3.new(3.6, 1.6, 8.4), deep)
		box(head, "Gape", Vector3.new(0, 18.05, -9.4), Vector3.new(4.3, 0.25, 8.6), Color3.fromRGB(60, 25, 15))
		box(head, "BeakTip", Vector3.new(0, 18.8, -15.3), Vector3.new(3.6, 3.2, 1.8), red)
		box(head, "BeakHook", Vector3.new(0, 16.9, -15.6), Vector3.new(3, 1.6, 1.6), red:Lerp(BLACK, 0.15))
		for _, side in { -1, 1 } do
			for i = 0, 5 do
				box(
					head,
					"Tooth",
					Vector3.new(side * 2.0, 17.75, -6.2 - i * 1.5),
					Vector3.new(0.4, 0.5, 0.7),
					deep:Lerp(BLACK, 0.2)
				)
			end
			box(head, "Nostril", Vector3.new(side * 2.15, 20.4, -6.2), Vector3.new(0.2, 0.9, 1), BLACK)
			box(head, "BeakGroove", Vector3.new(side * 2.17, 19.0, -9.6), Vector3.new(0.1, 0.25, 6.4), deep)
			box(
				head,
				"BeakShine",
				Vector3.new(side * 2.17, 20.6, -11.2),
				Vector3.new(0.1, 0.3, 4),
				Color3.fromRGB(255, 190, 90)
			)
		end
		v.swing(head, Vector3.new(0, 16, -0.5), Vector3.xAxis, 0.1, 3, 0, false, nil, "Head")

		-- Alas abiertas en escalones: cobertoras en filas con el borde claro, las remeras azuladas detrás en
		-- dedos que se estrechan hacia la punta, y el borde de ataque brillante.
		for _, side in { -1, 1 } do
			voxelWing(v, side, Vector3.new(side * 3.6, 14.5, 0.2), {
				{ center = Vector3.new(2, 0.1, 0.2), size = Vector3.new(4.6, 1.6, 5.6), color = color },
				{ center = Vector3.new(5.6, 0, 0.8), size = Vector3.new(3.6, 1.2, 4.8), color = color },
				{ center = Vector3.new(8.6, -0.1, 1.4), size = Vector3.new(3.2, 1, 3.8), color = color },
				{ center = Vector3.new(11.2, -0.2, 2), size = Vector3.new(2.2, 0.8, 2.8), color = color },
				{ center = Vector3.new(3.4, 0.9, -1.6), size = Vector3.new(6, 0.4, 2), color = sheen },
				{ center = Vector3.new(3, -0.3, 3.9), size = Vector3.new(4.6, 0.8, 2), color = sheen },
				{ center = Vector3.new(6.8, -0.3, 4.2), size = Vector3.new(3.6, 0.8, 2.6), color = sheen },
				{ center = Vector3.new(10.2, -0.3, 4), size = Vector3.new(2.8, 0.7, 3.4), color = sheen },
				{ center = Vector3.new(12.6, -0.3, 3.6), size = Vector3.new(2, 0.6, 2.8), color = sheen },
				-- Plumas pintadas: filas de cobertoras con borde claro y rayas en las remeras.
				{ center = Vector3.new(1.4, 1.0, 0.4), size = Vector3.new(1.6, 0.25, 4.6), color = gloss },
				{ center = Vector3.new(3.4, 1.0, 0.6), size = Vector3.new(1.6, 0.25, 4.2), color = sheen },
				{ center = Vector3.new(5.4, 0.7, 1.0), size = Vector3.new(1.6, 0.25, 3.8), color = gloss },
				{ center = Vector3.new(7.4, 0.7, 1.2), size = Vector3.new(1.4, 0.25, 3.4), color = sheen },
				{ center = Vector3.new(9.2, 0.5, 1.6), size = Vector3.new(1.4, 0.25, 3), color = gloss },
				{ center = Vector3.new(4.4, -0.75, 4.1), size = Vector3.new(0.25, 0.1, 1.8), color = gloss },
				{ center = Vector3.new(6.8, -0.75, 4.4), size = Vector3.new(0.25, 0.1, 2.2), color = gloss },
				{ center = Vector3.new(8.8, -0.75, 4.4), size = Vector3.new(0.25, 0.1, 2.2), color = gloss },
				{ center = Vector3.new(11, -0.65, 4.2), size = Vector3.new(0.25, 0.1, 2.4), color = gloss },
			}, 0.7, 14)
		end

		-- Cola cuadrada que cae hacia atrás en escalones (no inclinada: así entra en la malla), con las
		-- cobertoras encima, las plumas separadas por rayas y la punta azulada.
		local tailParts: { BasePart } = {}
		box(tailParts, "TailCovert", Vector3.new(0, 8.4, 4.5), Vector3.new(5.4, 1.4, 2.2), cream:Lerp(WHITE, 0.45))
		box(tailParts, "Tail", Vector3.new(0, 6.9, 5.4), Vector3.new(4.8, 2.0, 1.6), color)
		box(tailParts, "Tail", Vector3.new(0, 4.9, 6.2), Vector3.new(4.6, 2.2, 1.4), color)
		box(tailParts, "Tail", Vector3.new(0, 2.9, 7.0), Vector3.new(4.4, 1.9, 1.2), sheen)
		box(tailParts, "TailTip", Vector3.new(0, 1.1, 7.7), Vector3.new(4.2, 1.7, 1), red:Lerp(BLACK, 0.3))
		for i, x in { -1.6, -0.55, 0.55, 1.6 } do
			box(tailParts, "TailLine", Vector3.new(x, 6.9, 6.35), Vector3.new(0.25, 1.8, 0.1), BLACK)
			box(tailParts, "TailLine", Vector3.new(x, 4.9, 7.0), Vector3.new(0.25, 2.0, 0.1), BLACK)
			box(tailParts, "TailLine", Vector3.new(x, 2.9, 7.75), Vector3.new(0.25, 1.8, 0.1), BLACK)
			box(
				tailParts,
				"TailFeather",
				Vector3.new(x + 0.5, 1.1, 8.25),
				Vector3.new(0.5, 1.5, 0.1),
				if i % 2 == 0 then red else deep
			)
		end
		v.swing(tailParts, Vector3.new(0, 7, 3.6), Vector3.xAxis, 0.15, 6, 1, false, nil, "Tail")
		rig.family = "Bird"
		return "Fly"
	end,

	-- Colibrí voxel (docs/img/Colibri.jfif): verde con la gorguera morada, pecho lila que pasa a cian,
	-- antifaz verde oscuro, pico finísimo y largo, alas verdes con las puntas azules en escalones,
	-- cola en abanico de bandas verdes y azules, y patitas moradas.
	Colibri = function(rig, color)
		local v = voxelKit(rig, Vector3.new(0, 7.5, 0))
		local slim = 0.78 -- anchura relativa del cuerpo y la cabeza (el resto de ayudantes no la aplican: se ajustan a mano)
		local function box(list: { BasePart }?, name: string, center: Vector3, size: Vector3, paint: Color3): BasePart
			return v.box(
				list,
				name,
				Vector3.new(center.X * slim, center.Y, center.Z),
				Vector3.new(size.X * slim, size.Y, size.Z),
				paint
			)
		end
		local light = color:Lerp(Color3.fromRGB(150, 255, 120), 0.35)
		local dark = color:Lerp(BLACK, 0.45)
		local teal = Color3.fromRGB(35, 165, 185)
		local blue = Color3.fromRGB(30, 120, 215)
		local purple = Color3.fromRGB(120, 70, 210)
		local magenta = Color3.fromRGB(205, 60, 170)
		local lilac = Color3.fromRGB(150, 130, 230)
		local feet = Color3.fromRGB(85, 70, 105)
		local leaf = color:Lerp(Color3.fromRGB(20, 110, 60), 0.4) -- verde de sombra, para las filas de plumas

		for _, side in { -1, 1 } do
			local x = side * 1.1
			box(nil, "Leg", Vector3.new(x, 1.3, 0.4), Vector3.new(0.8, 1.6, 0.8), feet)
			box(nil, "Toe", Vector3.new(x, 0.3, -0.2), Vector3.new(0.9, 0.6, 1.8), feet)
			box(nil, "Claw", Vector3.new(x, 0.25, -1.3), Vector3.new(0.6, 0.4, 0.4), BLACK)
		end
		-- Barriga que empieza delgada sobre las patas y engrosa en tres escalones hasta el pecho, con plumas pintadas.
		box(nil, "Belly", Vector3.new(0, 2.6, 0.5), Vector3.new(3.4, 1.2, 4), color)
		box(nil, "Belly", Vector3.new(0, 3.8, 0.5), Vector3.new(4.2, 1.2, 4.6), color)
		box(nil, "Belly", Vector3.new(0, 5, 0.4), Vector3.new(4.8, 1.2, 5), color)
		box(nil, "Body", Vector3.new(0, 7.6, 0), Vector3.new(5.4, 4.2, 5.4), color)
		-- Por delante, de arriba abajo: gorguera morada (que rodea el cuello), pecho lila y vientre cian, con las
		-- plumas en filas.
		box(nil, "Breast", Vector3.new(0, 7, -2.85), Vector3.new(4.4, 2.4, 0.5), lilac)
		box(nil, "Breast", Vector3.new(0, 5.6, -2.85), Vector3.new(3.4, 1.2, 0.5), lilac:Lerp(teal, 0.5))
		box(nil, "BellyFront", Vector3.new(0, 4.4, -2.3), Vector3.new(2.6, 1.2, 0.3), teal)
		box(nil, "BellyFront", Vector3.new(0, 3.2, -1.95), Vector3.new(2.2, 1.2, 0.3), teal:Lerp(color, 0.3))
		box(nil, "BellyFront", Vector3.new(0, 2.2, -1.6), Vector3.new(1.8, 0.8, 0.3), teal:Lerp(color, 0.5))
		voxelScales(
			v,
			nil,
			"BreastFeather",
			"z",
			Vector3.new(0, 6.4, -3.2),
			Vector2.new(3.1, 3.2),
			Vector2.new(0.8, 0.8),
			{ lilac:Lerp(WHITE, 0.3), lilac:Lerp(teal, 0.35), lilac },
			0.2
		)
		-- Franja azulada en la espalda, de lado a lado (más estrecha parecía una mochila), y debajo las plumas
		-- verdes en filas con el borde azul.
		box(nil, "Mantle", Vector3.new(0, 8.2, 2.8), Vector3.new(5.5, 2.6, 0.3), teal)
		voxelScales(
			v,
			nil,
			"MantleFeather",
			"z",
			Vector3.new(0, 8.4, 3.05),
			Vector2.new(3.9, 2.4),
			Vector2.new(1, 0.8),
			{ teal:Lerp(WHITE, 0.2), blue, teal },
			0.2
		)
		voxelScales(
			v,
			nil,
			"BackFeather",
			"z",
			Vector3.new(0, 6.3, 2.85),
			Vector2.new(3.9, 1.6),
			Vector2.new(1, 0.8),
			{ light, leaf, color },
			0.2
		)
		-- Costados: plumas verdes en filas.
		for _, side in { -1, 1 } do
			voxelScales(
				v,
				nil,
				"FlankFeather",
				"x",
				Vector3.new(side * 2.2, 7.4, 0),
				Vector2.new(4.2, 3.6),
				Vector2.new(1, 0.9),
				{ light, color, leaf },
				0.2
			)
		end

		local head: { BasePart } = {}
		box(head, "Head", Vector3.new(0, 11.6, -0.8), Vector3.new(4.6, 4, 4.6), color)
		box(head, "Crown", Vector3.new(0, 13.75, -0.6), Vector3.new(3.8, 0.5, 3.6), light)
		box(head, "CrownFeather", Vector3.new(0, 14.1, -0.4), Vector3.new(2.6, 0.2, 2.6), light:Lerp(WHITE, 0.3))
		box(head, "Nape", Vector3.new(0, 11.4, 1.7), Vector3.new(3.8, 3.2, 0.3), leaf)
		box(head, "Gorget", Vector3.new(0, 9.4, -2.95), Vector3.new(4.2, 2.2, 0.6), purple)
		voxelScales(
			v,
			head,
			"GorgetFeather",
			"z",
			Vector3.new(0, 9.4, -3.3),
			Vector2.new(3.1, 2),
			Vector2.new(0.9, 0.7),
			{ magenta, purple, magenta:Lerp(purple, 0.5) },
			0.2
		)
		for _, side in { -1, 1 } do
			box(head, "GorgetSide", Vector3.new(side * 2.75, 9, -1.6), Vector3.new(0.3, 1.8, 2.4), purple)
			box(head, "GorgetSide", Vector3.new(side * 2.95, 9, -1.6), Vector3.new(0.1, 1.4, 2), magenta)
			box(head, "Mask", Vector3.new(side * 2.35, 11.7, -1.3), Vector3.new(0.3, 1.4, 3.4), dark)
			-- Ojo con capas (aro oscuro, iris, pupila y brillo) y la manchita blanca detrás del ojo.
			box(
				head,
				"EyeRing",
				Vector3.new(side * 2.55, 11.9, -1.6),
				Vector3.new(0.1, 1.7, 1.7),
				dark:Lerp(BLACK, 0.4)
			)
			box(
				head,
				"Iris",
				Vector3.new(side * 2.62, 11.9, -1.6),
				Vector3.new(0.1, 1.3, 1.3),
				Color3.fromRGB(90, 55, 35)
			)
			box(
				head,
				"Eye",
				Vector3.new(side * 2.68, 11.9, -1.6),
				Vector3.new(0.1, 0.9, 0.9),
				Color3.fromRGB(25, 20, 25)
			)
			box(head, "Glint", Vector3.new(side * 2.76, 12.15, -1.85), Vector3.new(0.1, 0.35, 0.35), WHITE)
			box(head, "EyeSpot", Vector3.new(side * 2.55, 11.6, -0.2), Vector3.new(0.1, 0.5, 0.8), WHITE)
		end
		-- Pico: una hilera finísima y larga, algo más gruesa en la base y que baja un poco hacia la punta.
		local beak = Color3.fromRGB(30, 60, 60)
		box(head, "BeakBase", Vector3.new(0, 11.4, -3.6), Vector3.new(1.2, 1, 1.2), beak:Lerp(feet, 0.3))
		box(head, "Beak", Vector3.new(0, 11.4, -5.2), Vector3.new(0.7, 0.7, 2.2), beak)
		box(head, "Beak", Vector3.new(0, 11.3, -7.4), Vector3.new(0.55, 0.55, 2.4), beak)
		box(head, "Beak", Vector3.new(0, 11.15, -9.6), Vector3.new(0.45, 0.45, 2.2), beak)
		box(head, "BeakShine", Vector3.new(0, 11.7, -6.2), Vector3.new(0.2, 0.1, 4.4), beak:Lerp(WHITE, 0.3))
		v.swing(head, Vector3.new(0, 9.6, -0.5), Vector3.xAxis, 0.1, 3, 0, false, nil, "Head")

		-- Alas verdes con las puntas azules en escalones y las plumas pintadas: cobertoras en filas y rayas en las
		-- remeras.
		for _, side in { -1, 1 } do
			voxelWing(v, side, Vector3.new(side * 2.1, 8.4, 0.6), {
				{ center = Vector3.new(1.8, 0.2, 0), size = Vector3.new(3.6, 1.2, 4), color = color },
				{ center = Vector3.new(4.9, 0.1, 0.6), size = Vector3.new(3, 0.9, 3.4), color = teal },
				{ center = Vector3.new(7.6, 0, 1.2), size = Vector3.new(2.8, 0.8, 2.8), color = blue },
				{ center = Vector3.new(3, -0.1, 2.8), size = Vector3.new(4, 0.6, 1.8), color = teal },
				{ center = Vector3.new(6.4, -0.1, 3), size = Vector3.new(3, 0.6, 2), color = blue },
				{
					center = Vector3.new(9.4, -0.1, 2.4),
					size = Vector3.new(1.6, 0.6, 2),
					color = blue:Lerp(BLACK, 0.2),
				},
				{
					center = Vector3.new(10.8, -0.1, 1.8),
					size = Vector3.new(1.4, 0.5, 1.6),
					color = blue:Lerp(BLACK, 0.35),
				},
				{ center = Vector3.new(1.4, 0.85, 0), size = Vector3.new(1.4, 0.25, 3.4), color = light },
				{ center = Vector3.new(3.2, 0.85, 0.1), size = Vector3.new(1.4, 0.25, 3.2), color = leaf },
				{
					center = Vector3.new(4.9, 0.6, 0.6),
					size = Vector3.new(1.4, 0.25, 2.8),
					color = teal:Lerp(WHITE, 0.25),
				},
				{
					center = Vector3.new(6.5, 0.5, 0.9),
					size = Vector3.new(1.2, 0.25, 2.4),
					color = blue:Lerp(WHITE, 0.2),
				},
				{ center = Vector3.new(3.4, -0.45, 2.9), size = Vector3.new(0.25, 0.1, 1.5), color = dark },
				{ center = Vector3.new(6.6, -0.45, 3.1), size = Vector3.new(0.25, 0.1, 1.7), color = dark },
				{ center = Vector3.new(9.4, -0.45, 2.5), size = Vector3.new(0.25, 0.1, 1.7), color = dark },
			}, 0.9, 45)
		end

		-- Cola en abanico: cinco plumas que bajan hacia atrás en escalones de bloques (no inclinadas: así entran en
		-- la malla), en bandas verde, azul, verde y azul.
		local tailParts: { BasePart } = {}
		local rump = Vector3.new(0, 3, 2.6)
		local bands = { { 3.4, color }, { 2, blue }, { 1.6, light }, { 1.6, blue } }
		for i = -2, 2 do
			local direction = Vector3.new(i * 0.2, -0.8, 0.75).Unit
			local reach = 1 - math.abs(i) * 0.12
			local from = rump + Vector3.new(i * 0.6, -math.abs(i) * 0.05, 0)
			for _, band in bands do
				local to = from + direction * band[1] * reach
				voxelStairs(v, tailParts, "TailFeather", from, to, Vector2.new(0.7, 0.5), band[2], 1.4)
				from = to
			end
		end
		v.swing(tailParts, rump, Vector3.xAxis, 0.15, 6, 1, false, nil, "Tail")
		return "Hover"
	end,

	-- Rana dardo voxel (docs/img/Rana dardo.jfif): azul con motas negras, lomo arqueado que sube hacia
	-- atrás, ojos negros saltones en bloque, boca en raya, vientre más claro, patas de delante finas
	-- y las de atrás plegadas en Z, con dedos planos y ventosas en la punta. Va a saltos.
	Rana = function(rig, color)
		local v = voxelKit(rig, Vector3.new(0, 4, 0))
		local box = v.box
		local belly = color:Lerp(WHITE, 0.25)
		local bellyLight = color:Lerp(WHITE, 0.5)
		local navy = color:Lerp(BLACK, 0.55)
		local legColor = color:Lerp(BLACK, 0.12)
		local spot = Color3.fromRGB(18, 18, 24)
		local sheen = color:Lerp(WHITE, 0.3) -- reflejo de la piel mojada
		local deep = color:Lerp(BLACK, 0.3)

		-- Cuerpo: la parte de delante algo más alta (está sentada sobre las patas de delante), el lomo
		-- y la joroba de la cadera encima, y la trasera redondeada que acaba en escalones. Los hombros y las ancas
		-- sobresalen de los costados.
		box(nil, "Body", Vector3.new(0, 3.2, 3.5), Vector3.new(8, 3.2, 5), color)
		box(nil, "Chest", Vector3.new(0, 3.9, -1.5), Vector3.new(8, 3.4, 5), color)
		box(nil, "Back", Vector3.new(0, 6.1, 1.2), Vector3.new(7, 1.8, 8.4), color)
		box(nil, "Hump", Vector3.new(0, 7.4, 2.4), Vector3.new(5.4, 1.2, 5), color)
		box(nil, "Rump", Vector3.new(0, 3.8, 6.4), Vector3.new(6, 3.4, 1), color)
		box(nil, "Rump", Vector3.new(0, 4.2, 7.1), Vector3.new(4.6, 2.4, 0.5), color)
		box(nil, "Belly", Vector3.new(0, 1.5, 1.6), Vector3.new(6.6, 0.3, 8.6), belly)
		for _, side in { -1, 1 } do
			box(nil, "Shoulder", Vector3.new(side * 4.3, 4.4, -1.6), Vector3.new(0.6, 2.4, 3.4), color:Lerp(deep, 0.15))
			box(nil, "Haunch", Vector3.new(side * 4.3, 4.2, 3.6), Vector3.new(0.6, 2.2, 3.6), color:Lerp(deep, 0.15))
		end
		-- Piel mojada: motitas claras y reflejos pintados entre las motas negras.
		for i = 1, 16 do
			local x = (((i * 5) % 9) - 4) * 0.7
			local z = -2.6 + i * 0.62
			local y = if z > -0.5 then 8.05 else 7.05
			if z > 5.3 then
				continue
			end
			box(
				nil,
				"Speck",
				Vector3.new(x, y, z),
				Vector3.new(0.5, 0.2, 0.5),
				if i % 3 == 0 then sheen else bellyLight
			)
		end
		for _, side in { -1, 1 } do
			for i = 1, 5 do
				box(
					nil,
					"Speck",
					Vector3.new(side * 4.65, 3.4 + (i % 3) * 0.7, -2.6 + i * 1.4),
					Vector3.new(0.2, 0.4, 0.5),
					if i % 2 == 0 then sheen else bellyLight
				)
			end
		end

		-- Cabeza ancha y plana con el hocico en escalón, la boca en raya oscura alrededor y la garganta
		-- clara con su saco vocal.
		box(nil, "Head", Vector3.new(0, 5.2, -5.4), Vector3.new(7.6, 3.6, 4.4), color)
		box(nil, "Snout", Vector3.new(0, 4.9, -8), Vector3.new(6, 2.6, 1.2), color)
		box(nil, "SnoutTip", Vector3.new(0, 4.6, -8.8), Vector3.new(4.4, 1.8, 0.5), color)
		box(nil, "Mouth", Vector3.new(0, 4.3, -6.075), Vector3.new(7.75, 0.3, 5.15), navy)
		box(nil, "Throat", Vector3.new(0, 3.4, -5.6), Vector3.new(6.6, 1, 4.6), belly)
		box(nil, "ThroatSac", Vector3.new(0, 2.7, -6.2), Vector3.new(5, 0.8, 3.4), bellyLight)
		for _, side in { -1, 1 } do
			-- Ojo negro saltón sobre su bulto azul, con el párpado y dos reflejos.
			box(nil, "EyeBump", Vector3.new(side * 2.7, 7.2, -5.6), Vector3.new(2.6, 1, 2.6), color)
			box(nil, "Eye", Vector3.new(side * 2.75, 8, -5.8), Vector3.new(2, 1.8, 2), spot)
			box(nil, "Lid", Vector3.new(side * 2.75, 9, -5.8), Vector3.new(2.2, 0.3, 2.2), deep)
			box(
				nil,
				"EyeShine",
				Vector3.new(side * 2.75, 8.4, -6.85),
				Vector3.new(1.2, 0.8, 0.1),
				Color3.fromRGB(70, 75, 95)
			)
			box(
				nil,
				"Glint",
				Vector3.new(side * 3.05, 8.5, -6.9),
				Vector3.new(0.6, 0.6, 0.1),
				Color3.fromRGB(150, 160, 180)
			)
			box(
				nil,
				"Glint",
				Vector3.new(side * 2.3, 7.9, -6.9),
				Vector3.new(0.3, 0.3, 0.1),
				Color3.fromRGB(110, 118, 135)
			)
			box(nil, "Nostril", Vector3.new(side * 0.9, 5.6, -8.62), Vector3.new(0.5, 0.4, 0.1), navy)
			box(nil, "Cheek", Vector3.new(side * 3.85, 5, -5), Vector3.new(0.2, 1.8, 2.8), sheen)
		end

		-- Motas negras: cuadros, barras y alguna L sobre la cabeza, el lomo, los costados y la trasera.
		-- { centro, tamaño }: la caja sobresale 0,1 de la cara en la que va.
		for _, mark in
			{
				-- Cabeza y lomo (por arriba).
				{ Vector3.new(-1, 7.05, -4.4), Vector3.new(1, 0.2, 1) },
				{ Vector3.new(1.2, 7.05, -3.7), Vector3.new(1.6, 0.2, 0.8) },
				{ Vector3.new(-1.2, 8.05, 1.2), Vector3.new(1.8, 0.2, 1) },
				{ Vector3.new(-0.7, 8.05, 1.9), Vector3.new(0.8, 0.2, 1.2) },
				{ Vector3.new(1.4, 8.05, 3.4), Vector3.new(1, 0.2, 1.6) },
				{ Vector3.new(0.1, 8.05, 4.4), Vector3.new(0.8, 0.2, 0.8) },
				{ Vector3.new(-2.8, 7.05, -1.6), Vector3.new(1, 0.2, 1.6) },
				{ Vector3.new(2.6, 7.05, -1), Vector3.new(1.2, 0.2, 1) },
				{ Vector3.new(2.95, 7.05, -0.5), Vector3.new(0.6, 0.2, 1.2) },
				{ Vector3.new(-3, 7.05, 4.6), Vector3.new(0.9, 0.2, 0.9) },
				{ Vector3.new(2.9, 7.05, 5), Vector3.new(1, 0.2, 0.8) },
				-- Costados.
				{ Vector3.new(4.05, 4, -1.6), Vector3.new(0.2, 1, 1.6) },
				{ Vector3.new(4.05, 4.4, 3), Vector3.new(0.2, 0.6, 1.6) },
				{ Vector3.new(-4.05, 4.2, -0.8), Vector3.new(0.2, 1, 1) },
				{ Vector3.new(-4.05, 3.4, -1.2), Vector3.new(0.2, 0.6, 1.4) },
				{ Vector3.new(-4.05, 4.35, 4.6), Vector3.new(0.2, 0.7, 1.2) },
				{ Vector3.new(3.55, 6.1, 2), Vector3.new(0.2, 0.8, 1.4) },
				{ Vector3.new(-3.55, 6.1, -1.4), Vector3.new(0.2, 0.8, 1) },
				{ Vector3.new(-3.85, 5.6, -4.6), Vector3.new(0.2, 1, 1) },
				{ Vector3.new(3.85, 4.9, -3.8), Vector3.new(0.2, 0.8, 0.8) },
				-- Trasera.
				{ Vector3.new(1, 4.2, 7.4), Vector3.new(1, 1, 0.2) },
				{ Vector3.new(-1.4, 3, 6.95), Vector3.new(0.8, 1, 0.2) },
				{ Vector3.new(-1.75, 3.6, 6.95), Vector3.new(0.6, 0.4, 0.2) },
				{ Vector3.new(0.6, 3.1, 6.95), Vector3.new(1.2, 0.8, 0.2) },
			}
		do
			box(nil, "Spot", mark[1], mark[2], spot)
		end

		-- Dedo plano con su ventosa en la punta, de "from" en la dirección "direction" (en el suelo), en escalones
		-- de bloques (no inclinado: así entra en la malla).
		local function finger(list: { BasePart }, from: Vector3, direction: Vector3, length: number, pad: Color3)
			local to = from + direction.Unit * length
			voxelFlat(v, list, "Toe", from, to, 0.5, 0.45, legColor)
			box(list, "ToePad", to + Vector3.new(0, 0.1, 0), Vector3.new(0.9, 0.7, 0.9), pad)
			box(list, "PadShine", to + Vector3.new(0, 0.5, 0), Vector3.new(0.4, 0.2, 0.4), pad:Lerp(WHITE, 0.4))
		end
		for _, side in { -1, 1 } do
			-- Pata de delante delgada y recta, con la mano de tres dedos abiertos.
			local front: { BasePart } = {}
			box(front, "FrontLeg", Vector3.new(side * 4.4, 2.3, -4.4), Vector3.new(1.2, 3.6, 1.2), legColor)
			box(
				front,
				"ElbowBump",
				Vector3.new(side * 4.4, 2.8, -3.6),
				Vector3.new(1.4, 1, 0.5),
				legColor:Lerp(BLACK, 0.2)
			)
			box(front, "Hand", Vector3.new(side * 4.6, 0.3, -4.7), Vector3.new(1.4, 0.6, 1.4), legColor)
			local palm = Vector3.new(side * 4.6, 0.25, -4.7)
			finger(front, palm, Vector3.new(side * -0.3, 0, -1), 1.9, spot)
			finger(front, palm, Vector3.new(side * 0.5, 0, -1), 1.9, legColor:Lerp(BLACK, 0.3))
			finger(front, palm, Vector3.new(side, 0, -0.25), 1.9, spot)

			-- Pata de atrás plegada en Z: muslo hacia delante, espinilla hacia atrás y pie con cuatro
			-- dedos largos abiertos hacia atrás y afuera.
			local back: { BasePart } = {}
			box(back, "Thigh", Vector3.new(side * 5, 2.8, 2.2), Vector3.new(2, 2.2, 5.4), legColor)
			box(back, "Shin", Vector3.new(side * 6.6, 1.5, 2.6), Vector3.new(1.6, 1.6, 5.2), legColor)
			box(back, "Knee", Vector3.new(side * 5.9, 2.4, -0.3), Vector3.new(2.4, 2, 1.4), legColor)
			box(back, "Foot", Vector3.new(side * 7.2, 0.3, 5.9), Vector3.new(1.8, 0.6, 2.2), legColor)
			-- Raya negra en el muslo, como en la referencia, y pelo de reflejos.
			box(back, "Spot", Vector3.new(side * 6.05, 3.3, 1.6), Vector3.new(0.2, 0.8, 1.6), spot)
			box(back, "ThighSheen", Vector3.new(side * 5, 3.95, 2.2), Vector3.new(1.2, 0.2, 3.4), sheen)
			box(back, "ShinSheen", Vector3.new(side * 6.6, 2.35, 2.6), Vector3.new(1, 0.2, 3.4), sheen)
			local heel = Vector3.new(side * 7.2, 0.25, 6.6)
			for k, direction in
				{
					Vector3.new(side * -0.25, 0, 1),
					Vector3.new(side * 0.2, 0, 1),
					Vector3.new(side * 0.7, 0, 0.8),
					Vector3.new(side, 0, 0.2),
				}
			do
				finger(back, heel, direction, if k == 2 or k == 3 then 2.6 else 2.1, if k % 2 == 0 then spot else navy)
			end

			-- Patalea al compás de los saltos (PetFollowers: |sin(reloj * 6)|), como la rana redonda:
			-- en el aire estira las traseras y adelanta las delanteras; con bias = amplitud no pasan al
			-- otro lado. Solo al andar.
			v.swing(
				back,
				Vector3.new(side * 3.6, 3.4, 4.2),
				Vector3.xAxis,
				0.22,
				12,
				-math.pi / 2,
				true,
				0.22,
				if side < 0 then "BL" else "BR"
			)
			v.swing(
				front,
				Vector3.new(side * 3.6, 3.8, -3.6),
				Vector3.xAxis,
				0.25,
				12,
				-math.pi / 2,
				true,
				0.25,
				if side < 0 then "FL" else "FR"
			)
		end
		return "Hop"
	end,

	-- Ajolote voxel (docs/img/Axololt voxel.jfif): la mascota mítica de la regeneración. Cuerpo largo y
	-- plano rosa perlado con la barriga clara y las motas iridiscentes del lomo; cabeza ancha con el
	-- hocico romo, la sonrisa curva con su labio, los ojitos en su cuenca bajo la ceja, las fosas y los
	-- pómulos con pecas; tres plumas de branquias carmesí a cada lado, cada una con sus filamentos y la
	-- punta en abanico, que se abren y se cierran; la cresta ondulada del lomo que sigue por la cola con
	-- su aleta, y las patitas finas con los dedos abiertos y sus almohadillas. Anda como una salamandra.
	-- Huesos de sus clips: Head, Tail, GillL, GillR, FL, FR, BL y BR.
	Ajolote = function(rig, color)
		local v = voxelKit(rig, Vector3.new(0, 4, 0))
		local box = v.box
		local belly = color:Lerp(WHITE, 0.6)
		local light = color:Lerp(WHITE, 0.3)
		local fin = color:Lerp(Color3.fromRGB(235, 60, 110), 0.4)
		local gill = Color3.fromRGB(228, 30, 85)
		local gillTip = Color3.fromRGB(255, 120, 160)
		local gillDark = gill:Lerp(BLACK, 0.3)
		local gillPale = gillTip:Lerp(WHITE, 0.35)
		local pearl = Color3.fromRGB(150, 235, 235)
		local violet = Color3.fromRGB(190, 160, 250)
		local dark = Color3.fromRGB(35, 22, 32)
		local blush = color:Lerp(gill, 0.35)
		local nostril = color:Lerp(BLACK, 0.35)

		-- Cuerpo largo y plano con la barriga clara, las rayas de las costillas y la hilera de puntos del
		-- costado.
		box(nil, "Body", Vector3.new(0, 3.8, 1.5), Vector3.new(5, 3.2, 10), color)
		box(nil, "Belly", Vector3.new(0, 2.2, 1.5), Vector3.new(4, 0.4, 9), belly)
		box(nil, "Back", Vector3.new(0, 5.5, 1.5), Vector3.new(3.6, 0.3, 9), light)
		for i, z in { -2.5, -0.5, 1.5, 3.5, 5, 6.2 } do
			local x = if i % 2 == 0 then 1 else -1
			box(
				nil,
				"Mote",
				Vector3.new(x * 0.9, 5.7, z),
				Vector3.new(0.8, 0.2, 0.8),
				if i % 2 == 0 then pearl else violet
			)
		end
		for _, side in { -1, 1 } do
			for _, z in { -1.5, 0.5, 2.5, 4.5 } do
				box(nil, "Rib", Vector3.new(side * 2.55, 3.9, z), Vector3.new(0.12, 2.4, 0.25), blush)
			end
		end
		-- Cresta del lomo: escalones de distinta altura que se siguen por la cola.
		for i, z in { -3, -1.8, -0.6, 0.6, 1.8, 3, 4.2, 5.4, 6.6 } do
			box(
				nil,
				"Crest",
				Vector3.new(0, 5.9 + (if i % 2 == 0 then 0.4 else 0), z),
				Vector3.new(0.5, 0.8 + (i % 2) * 0.6, 1),
				fin
			)
		end

		-- Cola: tres tramos que se afinan, con la aleta arriba y abajo. Ondea de lado a lado.
		local tailParts: { BasePart } = {}
		v.beam(tailParts, "Tail", Vector3.new(0, 3.7, 6), Vector3.new(0, 3.5, 10.5), Vector2.new(3.6, 3), color)
		v.beam(tailParts, "Tail", Vector3.new(0, 3.5, 10.5), Vector3.new(0, 3.3, 14.5), Vector2.new(2.6, 2.4), color)
		v.beam(tailParts, "Tail", Vector3.new(0, 3.3, 14.5), Vector3.new(0, 3.1, 18), Vector2.new(1.6, 1.8), color)
		for i, z in { 7, 8.8, 10.6, 12.4, 14.2, 16, 17.6 } do
			box(tailParts, "TailFin", Vector3.new(0, 5.4 - i * 0.14, z), Vector3.new(0.4, 1.4 - i * 0.1, 1.2), fin)
			box(tailParts, "TailFinLow", Vector3.new(0, 2.2 - i * 0.04, z + 0.4), Vector3.new(0.4, 0.8, 1), fin)
		end
		box(tailParts, "TailTip", Vector3.new(0, 3.1, 18.6), Vector3.new(0.6, 1.4, 0.8), gillDark)
		v.swing(tailParts, Vector3.new(0, 3.7, 6), Vector3.yAxis, 0.3, 4, 0, false, nil, "Tail")

		-- Cabeza ancha y plana: el hocico romo con su caballete, la ceja y la cuenca de cada ojo, las
		-- fosas, la sonrisa curva con el labio de abajo, los pómulos con pecas y el pliegue donde nacen
		-- las branquias; la cresta empieza ya en la nuca.
		local head: { BasePart } = {}
		box(head, "Head", Vector3.new(0, 3.9, -6.2), Vector3.new(7, 2.8, 5), color)
		box(head, "Snout", Vector3.new(0, 3.6, -9), Vector3.new(5.4, 2.2, 0.8), color)
		box(head, "HeadTop", Vector3.new(0, 5.4, -6.4), Vector3.new(5.6, 0.3, 4), light)
		box(head, "Chin", Vector3.new(0, 2.4, -6.4), Vector3.new(5.6, 0.4, 4.6), belly)
		box(head, "NoseBridge", Vector3.new(0, 4.9, -8.95), Vector3.new(1.6, 0.5, 0.6), light)
		box(head, "Pearl", Vector3.new(0, 5.6, -8.2), Vector3.new(0.6, 0.2, 0.6), pearl)
		box(head, "NapeCrest", Vector3.new(0, 5.8, -5.3), Vector3.new(0.5, 0.7, 0.9), fin)
		box(head, "NapeCrest", Vector3.new(0, 5.9, -4.2), Vector3.new(0.5, 1, 0.9), fin)
		-- Sonrisa: el centro más bajo y los extremos que suben, con sus hoyuelos.
		box(head, "Smile", Vector3.new(0, 3, -9.45), Vector3.new(1.8, 0.25, 0.2), dark)
		box(head, "LowerLip", Vector3.new(0, 2.7, -9.3), Vector3.new(2.6, 0.3, 0.4), belly)
		box(head, "MouthInside", Vector3.new(0, 2.88, -9.5), Vector3.new(1.4, 0.15, 0.1), gillTip)
		for _, side in { -1, 1 } do
			box(head, "Smile", Vector3.new(side * 1.3, 3.15, -9.45), Vector3.new(0.9, 0.25, 0.2), dark)
			box(head, "SmileEnd", Vector3.new(side * 1.95, 3.5, -9.45), Vector3.new(0.3, 0.5, 0.2), dark)
			box(head, "Dimple", Vector3.new(side * 2.35, 3.8, -9.4), Vector3.new(0.2, 0.25, 0.2), blush)
			box(head, "Brow", Vector3.new(side * 2.4, 5.45, -8.2), Vector3.new(1.4, 0.35, 0.9), light)
			box(head, "EyeSocket", Vector3.new(side * 2.4, 4.7, -8.76), Vector3.new(1.5, 1.5, 0.1), blush)
			box(head, "Eye", Vector3.new(side * 2.4, 4.7, -8.84), Vector3.new(0.9, 0.9, 0.1), dark)
			box(head, "Glint", Vector3.new(side * 2.2, 4.95, -8.92), Vector3.new(0.3, 0.3, 0.05), WHITE)
			box(head, "Glint", Vector3.new(side * 2.6, 4.5, -8.92), Vector3.new(0.15, 0.15, 0.05), pearl)
			box(head, "Nostril", Vector3.new(side * 0.6, 4.5, -9.4), Vector3.new(0.3, 0.3, 0.15), nostril)
			box(head, "Ridge", Vector3.new(side * 1.3, 5.6, -6.9), Vector3.new(0.5, 0.25, 2.4), light)
			box(head, "Cheek", Vector3.new(side * 3.55, 3.5, -7.6), Vector3.new(0.15, 1.1, 1.5), blush)
			box(
				head,
				"Fold",
				Vector3.new(side * 3.55, 4.6, -5.6),
				Vector3.new(0.2, 1.4, 1.6),
				color:Lerp(gillPale, 0.3)
			)
			for k, z in { -8.1, -7.4, -6.7 } do
				box(
					head,
					"Freckle",
					Vector3.new(side * 3.6, 3.15 + (k % 2) * 0.7, z),
					Vector3.new(0.1, 0.25, 0.25),
					gillDark
				)
			end
		end
		v.swing(head, Vector3.new(0, 3.9, -3.8), Vector3.yAxis, 0.08, 1.5, 0, false, nil, "Head")

		-- Branquias: tres plumas por lado (hacia arriba, hacia fuera y hacia abajo). Cada una nace de un
		-- bulto oscuro, tiene su tallo, tres pares de filamentos que se acortan hacia la punta y la
		-- punta en abanico, y se mezclan tres tonos. Se abren y se cierran despacio.
		for _, side in { -1, 1 } do
			local gills: { BasePart } = {}
			local base = Vector3.new(side * 3.5, 4.2, -4.8)
			local stalks = {
				Vector3.new(side * 5.4, 7.6, -4.6),
				Vector3.new(side * 6.8, 5.8, -5),
				Vector3.new(side * 6.2, 3.3, -5.4),
			}
			for index, to in stalks do
				local along = to - base
				local direction = along.Unit
				local across = Vector3.new(-direction.Y, direction.X, 0).Unit
				box(gills, "GillBase", base + direction * 0.3, Vector3.new(1.1, 1, 1.2), gillDark)
				v.beam(gills, "Gill", base, to, Vector2.new(0.8, 0.6), gill)
				for level, f in { 0.4, 0.65, 0.88 } do
					local at = base + along * f
					local reach = 1.9 - level * 0.4
					for _, sign in { -1, 1 } do
						local tip = at + across * sign * reach + direction * 0.9
						v.beam(
							gills,
							"Filament",
							at,
							tip,
							Vector2.new(0.4, 0.35),
							if (level + index) % 2 == 0 then gillTip else gill
						)
					end
				end
				box(gills, "GillTip", to, Vector3.new(1.1, 1.1, 0.7), gillTip)
				box(gills, "GillFan", to + direction * 0.8 + across * 0.5, Vector3.new(0.6, 0.6, 0.5), gillPale)
				box(gills, "GillFan", to + direction * 0.8 - across * 0.5, Vector3.new(0.6, 0.6, 0.5), gillPale)
			end
			v.swing(
				gills,
				Vector3.new(side * 3.4, 4.2, -4.8),
				Vector3.zAxis,
				0.12 * side,
				3,
				if side < 0 then 0 else math.pi,
				false,
				nil,
				if side < 0 then "GillL" else "GillR"
			)
		end

		-- Patitas finas que salen hacia fuera: el brazo, el antebrazo, la muñeca y la mano con cuatro dedos
		-- abiertos y su almohadilla en la punta.
		local function foot(list: { BasePart }, at: Vector3, front: boolean, side: number)
			box(list, "Hand", at, Vector3.new(1.2, 0.4, 1.2), belly)
			local toward = if front then -1 else 1
			for k = -1.5, 1.5 do
				local dir = Vector3.new(side * 0.55 + k * 0.5 * side, 0, toward * (1 - math.abs(k) * 0.2)).Unit
				v.beam(list, "Finger", at, at + dir * 1.5, Vector2.new(0.35, 0.3), belly)
				box(list, "Pad", at + dir * 1.6, Vector3.new(0.45, 0.35, 0.45), blush)
			end
		end
		for _, side in { -1, 1 } do
			local f: { BasePart } = {}
			v.beam(
				f,
				"Arm",
				Vector3.new(side * 2.5, 3, -2.6),
				Vector3.new(side * 4.4, 1.5, -3.2),
				Vector2.new(0.9, 0.9),
				color
			)
			v.beam(
				f,
				"Forearm",
				Vector3.new(side * 4.4, 1.5, -3.2),
				Vector3.new(side * 4.8, 0.5, -4.4),
				Vector2.new(0.8, 0.8),
				belly
			)
			foot(f, Vector3.new(side * 4.9, 0.3, -4.7), true, side)
			v.swing(
				f,
				Vector3.new(side * 2.5, 3, -2.6),
				Vector3.xAxis,
				0.35,
				5,
				if side < 0 then 0 else math.pi,
				true,
				nil,
				if side < 0 then "FL" else "FR"
			)
			local b: { BasePart } = {}
			v.beam(b, "Leg", Vector3.new(side * 2.5, 3, 5), Vector3.new(side * 4.6, 1.5, 5.8), Vector2.new(1, 1), color)
			v.beam(
				b,
				"Shin",
				Vector3.new(side * 4.6, 1.5, 5.8),
				Vector3.new(side * 5, 0.5, 7),
				Vector2.new(0.8, 0.8),
				belly
			)
			foot(b, Vector3.new(side * 5.1, 0.3, 7.3), false, side)
			v.swing(
				b,
				Vector3.new(side * 2.5, 3, 5),
				Vector3.xAxis,
				0.35,
				5,
				if side < 0 then math.pi else 0,
				true,
				nil,
				if side < 0 then "BL" else "BR"
			)
		end
		return "Walk"
	end,

	-- Tortuga verde voxel (docs/img/Tortuga verde.jfif): caparazón ancho y bajo en capas que se
	-- estrechan hacia arriba, con placas verde oliva, amarillas y marrones y el borde marrón oscuro;
	-- cabeza que asoma con escamas amarillas, aletas de delante largas en escalones y las de atrás
	-- cortas. Rema con las aletas al andar. Sus colores se pueden cambiar con una skin (SKINS, "tone").
	Tortuga = function(rig, color)
		local v = voxelKit(rig, Vector3.new(0, 4, 0))
		local box = v.box
		local skin = tone(rig, "skin", Color3.fromRGB(55, 110, 40))
		local skinDark = skin:Lerp(BLACK, 0.25)
		local scale = tone(rig, "scale", Color3.fromRGB(170, 155, 45))
		local olive = tone(rig, "olive", color:Lerp(Color3.fromRGB(110, 115, 25), 0.6))
		local yellow = tone(rig, "yellow", Color3.fromRGB(150, 140, 40))
		local brown = tone(rig, "brown", Color3.fromRGB(110, 72, 35))
		local rim = tone(rig, "rim", Color3.fromRGB(85, 55, 30))
		local plastron = tone(rig, "plastron", Color3.fromRGB(170, 155, 70))
		local eye = tone(rig, "eye", Color3.fromRGB(45, 20, 20))

		-- Caparazón: el peto abajo y cuatro capas, cada una en tres cajas (ancha, media y larga) para
		-- que la planta sea un óvalo en escalones. Cada capa de un tono: de lado se leen las bandas.
		box(nil, "Plastron", Vector3.new(0, 1.6, 0.5), Vector3.new(12, 1.2, 18), plastron)
		for _, layer in
			{
				{ 2.9, 1.4, Vector3.new(16, 0, 18), Vector3.new(13, 0, 21), Vector3.new(9, 0, 23), rim },
				{ 4.2, 1.2, Vector3.new(15, 0, 17), Vector3.new(12, 0, 20), Vector3.new(8, 0, 21.6), olive },
				{ 5.4, 1.2, Vector3.new(13, 0, 15), Vector3.new(10, 0, 18), Vector3.new(6, 0, 19), brown },
				{ 6.5, 1, Vector3.new(10, 0, 12), Vector3.new(7, 0, 15), Vector3.new(4, 0, 16), olive },
			}
		do
			for k = 3, 5 do
				box(nil, "Shell", Vector3.new(0, layer[1], 0.5), layer[k] + Vector3.new(0, layer[2], 0), layer[6])
			end
		end
		box(nil, "Shell", Vector3.new(0, 7.4, 0.5), Vector3.new(6, 0.8, 9), tone(rig, "crown", olive:Lerp(yellow, 0.3)))
		-- Placas de colores pegadas encima de cada capa: { x, y, z, ancho, fondo, color }.
		for _, plate in
			{
				{ 0, 7.85, -2.5, 3.5, 2.4, yellow },
				{ 0, 7.85, 1, 4, 2.2, brown },
				{ 0, 7.85, 3.6, 3, 1.6, yellow },
				{ 4, 7.05, -3, 1.8, 3, brown },
				{ 4.2, 7.05, 2.4, 1.6, 3, yellow },
				{ 2.4, 7.05, -6.4, 2.6, 1.2, yellow },
				{ 0, 7.05, 7, 3, 1.2, brown },
				{ 5.6, 6.05, -1, 1.2, 3, yellow },
				{ 5.5, 6.05, 4, 1.2, 2.4, brown },
				{ 3.4, 6.05, -8.2, 2.4, 1, brown },
				{ 2.6, 6.05, 8.6, 2, 1, yellow },
				{ 6.9, 4.85, 0, 1, 3, brown },
				{ 6.8, 4.85, -5, 1, 2, yellow },
				{ 6.5, 4.85, 5.2, 1, 2.4, yellow },
			}
		do
			for _, side in if plate[1] == 0 then { 1 } else { -1, 1 } do
				box(
					nil,
					"Plate",
					Vector3.new(plate[1] * side, plate[2], plate[3]),
					Vector3.new(plate[4], 0.2, plate[5]),
					plate[6]
				)
			end
		end

		-- Escudos del borde: placas verticales pintadas alrededor de las tres capas de abajo (alternando tonos) y las
		-- costuras de la corona. Todo fino: casi no cuesta triángulos.
		for i = 0, 8 do
			local z = -7.6 + i * 2.15
			for _, side in { -1, 1 } do
				box(
					nil,
					"Marginal",
					Vector3.new(side * 8.15, 2.9, z),
					Vector3.new(0.2, 1.1, 1.9),
					if i % 2 == 0 then brown else rim:Lerp(yellow, 0.35)
				)
				box(
					nil,
					"Marginal",
					Vector3.new(side * 7.65, 4.2, z + 0.5),
					Vector3.new(0.2, 0.9, 1.7),
					if i % 2 == 0 then yellow:Lerp(olive, 0.4) else olive:Lerp(brown, 0.5)
				)
				if i >= 1 and i <= 7 then
					box(
						nil,
						"Marginal",
						Vector3.new(side * 6.65, 5.4, z + 0.3),
						Vector3.new(0.2, 0.9, 1.6),
						if i % 2 == 0 then brown:Lerp(yellow, 0.3) else rim
					)
				end
			end
		end
		for i, x in { -3, -1.5, 0, 1.5, 3 } do
			box(
				nil,
				"Marginal",
				Vector3.new(x, 2.9, -11.1),
				Vector3.new(1.3, 1.1, 0.2),
				if i % 2 == 0 then brown else rim:Lerp(yellow, 0.35)
			)
			box(
				nil,
				"Marginal",
				Vector3.new(x, 2.9, 12.1),
				Vector3.new(1.3, 1.1, 0.2),
				if i % 2 == 0 then rim:Lerp(yellow, 0.35) else brown
			)
		end
		for _, x in { -1.8, 0, 1.8 } do
			box(nil, "Seam", Vector3.new(x, 8, 0.5), Vector3.new(0.25, 0.1, 8.4), rim)
		end
		for _, z in { -1.4, 2.2, 5.2 } do
			box(nil, "Seam", Vector3.new(0, 8, z), Vector3.new(5.6, 0.1, 0.25), rim)
		end

		-- Cabeza que asoma con el cuello, el hocico romo en escalón, la boca en raya y escamas amarillas.
		local head: { BasePart } = {}
		box(head, "Neck", Vector3.new(0, 3.4, -11), Vector3.new(4, 2.8, 3), skin)
		box(head, "Head", Vector3.new(0, 4, -14), Vector3.new(5, 3.8, 4.6), skin)
		box(head, "Snout", Vector3.new(0, 3.6, -16.8), Vector3.new(4, 2.8, 1.2), skin)
		box(head, "Mouth", Vector3.new(0, 3, -16.3), Vector3.new(4.1, 0.25, 2.3), skinDark:Lerp(BLACK, 0.4))
		for _, side in { -1, 1 } do
			box(head, "EyeRing", Vector3.new(side * 2.52, 4.6, -15), Vector3.new(0.12, 1.6, 1.6), skinDark)
			box(
				head,
				"Iris",
				Vector3.new(side * 2.6, 4.6, -15),
				Vector3.new(0.1, 1.2, 1.2),
				Color3.fromRGB(150, 110, 40)
			)
			box(head, "Eye", Vector3.new(side * 2.66, 4.6, -15), Vector3.new(0.1, 0.8, 0.8), eye)
			box(head, "Glint", Vector3.new(side * 2.73, 4.85, -15.25), Vector3.new(0.1, 0.35, 0.35), WHITE)
			box(head, "Lid", Vector3.new(side * 2.6, 5.45, -15), Vector3.new(0.12, 0.25, 1.5), skin)
			box(head, "Nostril", Vector3.new(side * 0.8, 4.4, -17.45), Vector3.new(0.4, 0.4, 0.1), skinDark)
			for _, spot in { { 3.6, -13 }, { 5, -12.6 }, { 3.4, -14.3 }, { 5.3, -13.9 } } do
				box(head, "Scale", Vector3.new(side * 2.55, spot[1], spot[2]), Vector3.new(0.2, 0.8, 0.8), scale)
			end
		end
		for _, spot in { { -1, -13 }, { 1, -13.4 }, { 0, -14.6 }, { -1.3, -15.4 }, { 1.2, -15.7 }, { 0, -12.1 } } do
			box(head, "Scale", Vector3.new(spot[1], 5.95, spot[2]), Vector3.new(0.8, 0.2, 0.8), scale)
		end
		for _, z in { -11.6, -10.6, -9.6 } do
			box(head, "NeckFold", Vector3.new(0, 4.85, z), Vector3.new(3.4, 0.2, 0.3), skinDark)
		end
		v.swing(head, Vector3.new(0, 3.5, -10), Vector3.yAxis, 0.3, 1.5, 0, false, nil, "Head")

		-- Aletas: las de delante, largas, en cuatro escalones que bajan hacia la punta, con escamas
		-- amarillas; las de atrás, cortas. Reman hacia atrás las dos a la vez (giro en Y).
		for _, side in { -1, 1 } do
			local front: { BasePart } = {}
			box(front, "Flipper", Vector3.new(side * 8, 2.2, -6.5), Vector3.new(4, 1.2, 4), skin)
			box(front, "Flipper", Vector3.new(side * 11, 1.6, -5.5), Vector3.new(3.6, 1, 3.4), skin)
			box(front, "Flipper", Vector3.new(side * 13.6, 1, -4.2), Vector3.new(2.6, 0.9, 2.8), skin)
			box(front, "Flipper", Vector3.new(side * 15.6, 0.5, -2.8), Vector3.new(1.8, 0.8, 2), skin)
			box(front, "FlipperEdge", Vector3.new(side * 9.4, 1.75, -4.3), Vector3.new(5, 0.9, 0.6), skinDark)
			for _, spot in { { 7.4, 2.85, -7.2 }, { 9.2, 2.85, -5.6 }, { 11.4, 2.15, -6 }, { 13.4, 1.5, -4.6 } } do
				box(front, "Scale", Vector3.new(side * spot[1], spot[2], spot[3]), Vector3.new(0.8, 0.2, 0.8), scale)
			end
			for _, z in { -3.4, -2.2 } do
				box(
					front,
					"Claw",
					Vector3.new(side * 16.9, 0.4, z),
					Vector3.new(0.8, 0.5, 0.6),
					scale:Lerp(WHITE, 0.45)
				)
			end
			voxelTopScales(
				v,
				front,
				"FlipperScale",
				Vector3.new(side * 11, 2.15, -5.5),
				Vector2.new(3.2, 3),
				Vector2.new(0.9, 0.9),
				{ scale, skinDark, skin:Lerp(scale, 0.3) },
				0.15
			)
			voxelTopScales(
				v,
				front,
				"FlipperScale",
				Vector3.new(side * 13.6, 1.5, -4.2),
				Vector2.new(2.2, 2.4),
				Vector2.new(0.9, 0.9),
				{ scale, skinDark },
				0.15
			)
			v.swing(
				front,
				Vector3.new(side * 6, 2.4, -6),
				Vector3.yAxis,
				0.3 * side,
				5,
				0,
				true,
				nil,
				if side < 0 then "FL" else "FR"
			)

			local back: { BasePart } = {}
			box(back, "Flipper", Vector3.new(side * 5.5, 1.2, 10.8), Vector3.new(3, 1, 3), skin)
			box(back, "Flipper", Vector3.new(side * 6.8, 0.7, 12.6), Vector3.new(2.6, 0.8, 2.6), skin)
			box(back, "Scale", Vector3.new(side * 5.5, 1.8, 10.6), Vector3.new(0.8, 0.2, 0.8), scale)
			v.swing(
				back,
				Vector3.new(side * 4.5, 1.6, 9.5),
				Vector3.yAxis,
				-0.25 * side,
				5,
				math.pi,
				true,
				nil,
				if side < 0 then "BL" else "BR"
			)
		end
		-- Colita cónica de dos bloques.
		box(nil, "Tail", Vector3.new(0, 1.8, 12), Vector3.new(1.4, 1, 2), skin)
		box(nil, "Tail", Vector3.new(0, 1.4, 13.3), Vector3.new(0.8, 0.6, 1), skin)
		return "Walk"
	end,

	-- Guacamaya roja voxel (docs/img/Guacamaya.jfif): esbelta y alargada, roja, con la cara blanca y el
	-- ojo negro, pico enorme y ganchudo blanco con la mandíbula negra, alas largas rojas con la banda
	-- amarilla y las remeras azules, y cola larguísima y en punta, roja en el centro y azul por los
	-- lados. Vuela, así que lleva las alas abiertas en escalones, como el tucán.
	Guacamaya = function(rig, color)
		local v = voxelKit(rig, Vector3.new(0, 12, 0))
		local box = v.box
		local deep = color:Lerp(BLACK, 0.15)
		local bright = color:Lerp(Color3.fromRGB(255, 120, 60), 0.25)
		local yellow = Color3.fromRGB(245, 195, 30)
		local green = Color3.fromRGB(70, 150, 60)
		local blue = Color3.fromRGB(30, 85, 210)
		local deepBlue = Color3.fromRGB(25, 50, 150)
		local horn = Color3.fromRGB(235, 228, 215)
		local hornShade = horn:Lerp(Color3.fromRGB(150, 140, 130), 0.5)
		local feet = Color3.fromRGB(125, 112, 112)

		-- Patas: dos dedos delante (con una rendija) y dos detrás, para trepar, con escamas y uñas.
		for _, side in { -1, 1 } do
			local x = side * 1.5
			box(nil, "Leg", Vector3.new(x, 2.9, 0.6), Vector3.new(1.2, 3.8, 1.2), feet)
			for _, y in { 3.8, 2.8, 1.8 } do
				box(nil, "Scale", Vector3.new(x, y, -0.05), Vector3.new(1, 0.4, 0.1), feet:Lerp(BLACK, 0.4))
			end
			box(nil, "Toe", Vector3.new(x, 0.4, -0.5), Vector3.new(1.8, 0.8, 2.8), feet)
			box(nil, "ToeGap", Vector3.new(x, 0.45, -1.4), Vector3.new(0.2, 0.75, 1.1), feet:Lerp(BLACK, 0.5))
			box(nil, "Toe", Vector3.new(x, 0.4, 1.8), Vector3.new(1.6, 0.8, 1.6), feet)
			box(nil, "Claw", Vector3.new(x, 0.3, -2.05), Vector3.new(1.8, 0.6, 0.3), Color3.fromRGB(50, 45, 45))
			-- Muslo emplumado.
			box(nil, "Thigh", Vector3.new(side * 3.4, 6.4, 0.6), Vector3.new(0.7, 3.4, 3.6), deep)
		end

		-- Cuerpo alto y estrecho que engrosa de abajo arriba (la barriga empieza delgada sobre las patas y se
		-- ensancha en tres escalones hasta el pecho), con el lomo en dos escalones (de espaldas no es una losa).
		box(nil, "Belly", Vector3.new(0, 5.3, 0.8), Vector3.new(4.2, 1.6, 5), color)
		box(nil, "Belly", Vector3.new(0, 6.9, 0.8), Vector3.new(5.2, 1.6, 5.8), color)
		box(nil, "Belly", Vector3.new(0, 8.75, 0.8), Vector3.new(6.4, 2.1, 6.6), color)
		box(nil, "Body", Vector3.new(0, 12.6, 0), Vector3.new(7, 5.6, 6.6), color)
		box(nil, "Shoulders", Vector3.new(0, 16.8, 0), Vector3.new(6.2, 3, 6.4), color)
		box(nil, "Neck", Vector3.new(0, 19.4, -0.4), Vector3.new(5.2, 2.6, 5.4), color)
		box(nil, "Mantle", Vector3.new(0, 14, 3.45), Vector3.new(5.4, 6, 0.4), deep)
		box(nil, "Mantle", Vector3.new(0, 9.4, 4.25), Vector3.new(4, 2.6, 0.4), deep:Lerp(BLACK, 0.12))
		-- Plumas pintadas: pecho, espalda y costados en filas de dos o tres tonos.
		voxelScales(
			v,
			nil,
			"ChestFeather",
			"z",
			Vector3.new(0, 14, -3.45),
			Vector2.new(5.6, 7.6),
			Vector2.new(1.2, 1),
			{ bright, color, deep },
			0.2
		)
		voxelScales(
			v,
			nil,
			"BackFeather",
			"z",
			Vector3.new(0, 14.2, 3.8),
			Vector2.new(4.8, 5.6),
			Vector2.new(1.2, 1),
			{ deep, color, bright },
			0.2
		)
		voxelScales(
			v,
			nil,
			"BackFeather",
			"z",
			Vector3.new(0, 9.4, 4.6),
			Vector2.new(3.6, 2.4),
			Vector2.new(1.2, 1),
			{ deep:Lerp(BLACK, 0.2), deep },
			0.2
		)
		for _, side in { -1, 1 } do
			voxelScales(
				v,
				nil,
				"FlankFeather",
				"x",
				Vector3.new(side * 3.55, 12.4, 0),
				Vector2.new(5.4, 4.6),
				Vector2.new(1.2, 1),
				{ color, bright, deep },
				0.2
			)
		end

		-- Cabeza: bloque rojo y cara blanca a los lados con las líneas de plumitas rojas, el ojo con su iris
		-- amarillo y el brillo.
		local head: { BasePart } = {}
		local up = Vector3.new(0, 2.6, 0)
		box(head, "Head", Vector3.new(0, 19, -0.6) + up, Vector3.new(6.2, 5.6, 6.2), color)
		box(
			head,
			"Crown",
			Vector3.new(0, 22.2, -0.4) + up,
			Vector3.new(5.2, 0.8, 5),
			color:Lerp(Color3.fromRGB(255, 110, 40), 0.2)
		)
		voxelScales(
			v,
			head,
			"CrownFeather",
			"z",
			Vector3.new(0, 22.7, -0.4) + up,
			Vector2.new(4.6, 0.2),
			Vector2.new(0.9, 0.2),
			{ bright, color },
			4.2
		)
		box(head, "Nape", Vector3.new(0, 18.8, 2.65) + up, Vector3.new(5, 4.4, 0.4), deep)
		for _, side in { -1, 1 } do
			box(head, "Face", Vector3.new(side * 3.15, 18.4, -2.3) + up, Vector3.new(0.3, 3.8, 3.6), WHITE)
			box(head, "FaceFront", Vector3.new(side * 2, 17.6, -3.75) + up, Vector3.new(2.2, 2.4, 0.3), WHITE)
			-- Líneas de plumitas rojas sobre la cara blanca.
			for k, y in { 17.5, 18.4, 19.3 } do
				box(
					head,
					"FaceLine",
					Vector3.new(side * 3.35, y, -2.2 - (k % 2) * 0.3) + up,
					Vector3.new(0.1, 0.25, 2.4 - (k % 2) * 0.4),
					deep
				)
			end
			box(
				head,
				"EyeRing",
				Vector3.new(side * 3.33, 19.4, -2.1) + up,
				Vector3.new(0.12, 2, 2),
				horn:Lerp(color, 0.2)
			)
			box(head, "Iris", Vector3.new(side * 3.42, 19.4, -2.1) + up, Vector3.new(0.1, 1.5, 1.5), yellow)
			box(head, "Eye", Vector3.new(side * 3.5, 19.4, -2.1) + up, Vector3.new(0.1, 1, 1), BLACK)
			box(head, "Glint", Vector3.new(side * 3.58, 19.7, -2.35) + up, Vector3.new(0.1, 0.45, 0.45), WHITE)
		end
		-- Pico enorme: mandíbula de arriba clara en tres escalones que bajan en gancho con la punta
		-- oscura, la cera sobre la base, las fosas y la mandíbula de abajo negra, más ancha que el gancho.
		box(head, "BeakBase", Vector3.new(0, 19.2, -4.3) + up, Vector3.new(4, 3.6, 1.6), horn)
		box(head, "Beak", Vector3.new(0, 19, -5.9) + up, Vector3.new(3.4, 3.2, 2), horn)
		box(head, "BeakRidge", Vector3.new(0, 20.7, -5.4) + up, Vector3.new(2.2, 0.4, 3), hornShade)
		box(head, "BeakHook", Vector3.new(0, 16.9, -6.7) + up, Vector3.new(2.6, 2.4, 1.6), horn)
		box(head, "BeakTip", Vector3.new(0, 15.4, -6.6) + up, Vector3.new(1.6, 1, 1.2), Color3.fromRGB(60, 58, 62))
		box(head, "LowerBeak", Vector3.new(0, 16.3, -4.8) + up, Vector3.new(3.8, 2.4, 2.8), BLACK)
		for _, side in { -1, 1 } do
			box(
				head,
				"Nostril",
				Vector3.new(side * 1.2, 20.1, -4.3) + up,
				Vector3.new(0.5, 0.5, 0.5),
				hornShade:Lerp(BLACK, 0.5)
			)
			box(head, "BeakSide", Vector3.new(side * 1.72, 18.6, -5.9) + up, Vector3.new(0.1, 0.3, 1.6), hornShade)
		end
		v.swing(head, Vector3.new(0, 18.6, -0.5), Vector3.xAxis, 0.1, 3, 0, false, nil, "Head")

		-- Alas largas abiertas: brazo rojo con las cobertoras en filas, banda amarilla con el borde verde y
		-- remeras azules que se oscurecen hacia la punta y se separan en dedos.
		for _, side in { -1, 1 } do
			voxelWing(v, side, Vector3.new(side * 3.4, 15.6, 0.2), {
				{ center = Vector3.new(3, 0.1, -0.4), size = Vector3.new(6.9, 1.6, 4.2), color = color },
				{ center = Vector3.new(8.4, 0.05, -0.2), size = Vector3.new(4.5, 1.4, 3.4), color = color },
				{ center = Vector3.new(5.4, 0, 2.6), size = Vector3.new(9.3, 1.2, 2), color = yellow },
				{ center = Vector3.new(5.4, -0.1, 3.9), size = Vector3.new(8.4, 1, 0.8), color = green },
				{ center = Vector3.new(12.9, -0.1, 1.2), size = Vector3.new(4.8, 1, 4.4), color = blue },
				{ center = Vector3.new(4.5, -0.3, 5.3), size = Vector3.new(6.9, 0.8, 2.2), color = blue },
				{ center = Vector3.new(10.2, -0.3, 4.8), size = Vector3.new(5.4, 0.8, 3), color = blue },
				{ center = Vector3.new(15.3, -0.3, 3.8), size = Vector3.new(4.2, 0.7, 3.4), color = deepBlue },
				{ center = Vector3.new(17.85, -0.3, 2.4), size = Vector3.new(2.1, 0.6, 2), color = deepBlue },
				{
					center = Vector3.new(19.4, -0.3, 1.8),
					size = Vector3.new(1.4, 0.5, 1.4),
					color = deepBlue:Lerp(BLACK, 0.3),
				},
				{ center = Vector3.new(1.6, 1.0, -0.4), size = Vector3.new(2.4, 0.25, 3.8), color = bright },
				{ center = Vector3.new(4, 1.0, -0.4), size = Vector3.new(2.4, 0.25, 3.8), color = deep },
				{ center = Vector3.new(6.4, 1.0, -0.4), size = Vector3.new(2.4, 0.25, 3.8), color = bright },
				{ center = Vector3.new(8.8, 0.8, -0.2), size = Vector3.new(2.2, 0.25, 3), color = deep },
				{ center = Vector3.new(11, 0.8, -0.2), size = Vector3.new(1.8, 0.25, 2.6), color = bright },
				{ center = Vector3.new(7.4, -0.75, 4.9), size = Vector3.new(0.25, 0.1, 2.4), color = deepBlue },
				{ center = Vector3.new(10.4, -0.75, 4.9), size = Vector3.new(0.25, 0.1, 2.4), color = deepBlue },
				{ center = Vector3.new(13.4, -0.75, 4.4), size = Vector3.new(0.25, 0.1, 2.4), color = BLACK },
				{ center = Vector3.new(16, -0.65, 4), size = Vector3.new(0.25, 0.1, 2.4), color = BLACK },
			}, 0.7, 12)
		end

		-- Cola larguísima y en punta, en escalones de bloques (no inclinada: así entra en la malla): cobertoras
		-- rojas, la pluma del centro roja con la punta azul y dos azules más cortas a los lados.
		local tailParts: { BasePart } = {}
		voxelStairs(
			v,
			tailParts,
			"TailCovert",
			Vector3.new(0, 9.4, 3.4),
			Vector3.new(0, 6.2, 8),
			Vector2.new(4.6, 1.4),
			color,
			1.6
		)
		voxelStairs(
			v,
			tailParts,
			"Tail",
			Vector3.new(0, 7.6, 4),
			Vector3.new(0, 1.6, 17.2),
			Vector2.new(2.4, 1),
			color,
			2
		)
		voxelStairs(
			v,
			tailParts,
			"TailTip",
			Vector3.new(0, 1.6, 17.2),
			Vector3.new(0, 0.4, 21),
			Vector2.new(1.6, 0.9),
			blue,
			1.4
		)
		for _, side in { -1, 1 } do
			voxelStairs(
				v,
				tailParts,
				"TailSide",
				Vector3.new(side * 1.5, 7.4, 4.2),
				Vector3.new(side * 1.9, 2.6, 13.4),
				Vector2.new(1.8, 0.9),
				blue,
				2
			)
		end
		v.swing(tailParts, Vector3.new(0, 7.6, 3.6), Vector3.xAxis, 0.15, 6, 1, false, nil, "Tail")
		rig.family = "Bird"
		return "Fly"
	end,

	-- Quetzal voxel (docs/img/quetzal Voxel 1.jfif y 2): el ave sagrada, mítica. Esmeralda intenso con
	-- reflejos dorados y turquesa, la pechuga carmesí en escamas bien marcada y la barriga rosada que
	-- se estrecha hacia la cola, con los muslos de plumas, las patas con sus dedos a la vista, el pico
	-- amarillo corto, la cresta sobre la cabeza, las alas abiertas con las remeras en verde oscuro y una
	-- franja pálida, la cola blanca por debajo y dos plumas larguísimas que cuelgan y se enroscan.
	-- Vuela. Distinta de la Guacamaya (roja y azul, cola en punta) y del Tucán (negro, pico enorme).
	Quetzal = function(rig, color)
		local v = voxelKit(rig, Vector3.new(0, 12, 0))
		local slim = 0.84 -- anchura relativa del cuerpo y la cabeza (el resto de ayudantes no la aplican: se ajustan a mano)
		local function box(list: { BasePart }?, name: string, center: Vector3, size: Vector3, paint: Color3): BasePart
			return v.box(
				list,
				name,
				Vector3.new(center.X * slim, center.Y, center.Z),
				Vector3.new(size.X * slim, size.Y, size.Z),
				paint
			)
		end
		local deep = color:Lerp(Color3.fromRGB(5, 70, 50), 0.55)
		local darkest = color:Lerp(Color3.fromRGB(4, 30, 30), 0.82)
		local teal = color:Lerp(Color3.fromRGB(0, 215, 180), 0.5)
		local gold = Color3.fromRGB(170, 235, 70)
		local crimson = Color3.fromRGB(228, 18, 52)
		local crimsonDark = Color3.fromRGB(150, 10, 38)
		local crimsonLight = Color3.fromRGB(245, 70, 90)
		local rose = Color3.fromRGB(226, 80, 96)
		local yellow = Color3.fromRGB(250, 205, 35)
		local pale = Color3.fromRGB(185, 235, 205)
		local feet = Color3.fromRGB(70, 50, 58)

		-- Patas con el muslo de plumas verde-turquesa, la caña fina y los dedos: tres hacia delante y uno
		-- hacia atrás, con uñas.
		for _, side in { -1, 1 } do
			local x = side * 1.6
			box(nil, "Thigh", Vector3.new(side * 2.4, 5.8, 0.6), Vector3.new(1.6, 3, 3.2), deep)
			box(nil, "ThighEdge", Vector3.new(side * 2.4, 4.1, 0.6), Vector3.new(1.4, 0.7, 2.6), teal)
			voxelScales(
				v,
				nil,
				"ThighFeather",
				"x",
				Vector3.new(side * 2.75, 5.8, 0.6),
				Vector2.new(3, 2.8),
				Vector2.new(0.9, 0.7),
				{ teal, deep, color },
				0.2
			)
			box(nil, "Leg", Vector3.new(x, 3.1, 0.6), Vector3.new(0.8, 2.2, 0.8), feet)
			for k = -1, 1 do
				-- Dedos de 0,5 de ancho (con el factor de anchura quedan en 0,42): más finos se pintaban sobre la pata.
				box(nil, "Toe", Vector3.new(x + k * 0.62, 1.9, -0.5), Vector3.new(0.5, 0.5, 1.8), feet)
				box(nil, "Claw", Vector3.new(x + k * 0.62, 1.8, -1.6), Vector3.new(0.5, 0.4, 0.5), BLACK)
			end
			box(nil, "Toe", Vector3.new(x, 1.9, 1.6), Vector3.new(0.5, 0.5, 1), feet)
		end

		-- Cuerpo que se estrecha hacia abajo en tres tramos: hombros anchos, cintura y cola. La espalda
		-- verde lleva la capa en filas y el pecho el peto carmesí en escamas; la barriga, más baja y
		-- rosada, queda separada por una línea oscura.
		box(nil, "Body", Vector3.new(0, 11.4, 0.5), Vector3.new(5.6, 3.6, 6), color)
		box(nil, "Waist", Vector3.new(0, 8.2, 0.7), Vector3.new(4.8, 3, 5.4), color)
		box(nil, "Lower", Vector3.new(0, 5.9, 1), Vector3.new(3.6, 2, 4.6), deep)
		box(nil, "Shoulders", Vector3.new(0, 13.4, 0.2), Vector3.new(5.2, 1.4, 5.4), teal)
		box(nil, "ShoulderGold", Vector3.new(0, 14.2, 0.1), Vector3.new(4, 0.4, 4.4), gold)
		box(nil, "Neck", Vector3.new(0, 14.9, -0.2), Vector3.new(4.4, 1.6, 4.4), color)
		box(nil, "Bib", Vector3.new(0, 11.8, -2.55), Vector3.new(4.6, 2.4, 0.5), crimson)
		box(nil, "Bib", Vector3.new(0, 9.8, -2.35), Vector3.new(4.2, 1.8, 0.5), crimsonDark)
		box(nil, "Bib", Vector3.new(0, 8.6, -2.2), Vector3.new(3.8, 0.9, 0.4), crimson)
		box(nil, "BibEdge", Vector3.new(0, 13.2, -2.6), Vector3.new(3, 0.5, 0.4), crimsonDark)
		box(nil, "NeckRing", Vector3.new(0, 14.1, -0.2), Vector3.new(4.8, 0.3, 4.6), gold:Lerp(color, 0.25))
		box(nil, "Epaulette", Vector3.new(0, 13.95, 0.1), Vector3.new(6, 0.3, 5.6), gold:Lerp(teal, 0.4))
		box(nil, "BellyLine", Vector3.new(0, 7.9, -2.25), Vector3.new(3.2, 0.3, 0.3), darkest)
		box(nil, "Belly", Vector3.new(0, 6.5, -1.8), Vector3.new(3, 1.6, 0.5), rose)
		box(nil, "Belly", Vector3.new(0, 5.4, -0.2), Vector3.new(2.8, 0.6, 3.6), rose)
		-- Escamas del peto: filas de plumitas carmesí en tres tonos y en la barriga rosada.
		voxelScales(
			v,
			nil,
			"BibScale",
			"z",
			Vector3.new(0, 10.7, -2.9),
			Vector2.new(3.7, 4.2),
			Vector2.new(1, 0.8),
			{ crimsonLight, crimson, crimsonDark },
			0.2
		)
		voxelScales(
			v,
			nil,
			"BellyScale",
			"z",
			Vector3.new(0, 6.7, -2.1),
			Vector2.new(2.4, 1.6),
			Vector2.new(0.9, 0.7),
			{ rose, rose:Lerp(WHITE, 0.3) },
			0.2
		)
		for _, side in { -1, 1 } do
			box(nil, "Flank", Vector3.new(side * 2.55, 9.2, -0.6), Vector3.new(0.3, 3.4, 3.4), crimsonDark)
			box(nil, "Flank", Vector3.new(side * 2.15, 7, 0.2), Vector3.new(0.3, 1.6, 2.6), crimson)
			box(nil, "BackFlank", Vector3.new(side * 2.85, 10.2, 2.4), Vector3.new(0.3, 2.4, 2.4), crimsonDark)
			voxelScales(
				v,
				nil,
				"FlankScale",
				"x",
				Vector3.new(side * 2.4, 11.6, -0.2),
				Vector2.new(4.4, 2.2),
				Vector2.new(1, 0.8),
				{ color, teal, deep },
				0.2
			)
		end

		-- Capa de la espalda en filas que se estrechan, alternando tonos con un reflejo dorado, y la
		-- banda blanca antes de la cola (de espaldas no es una losa). Encima, filas de plumas pintadas.
		box(nil, "Cape", Vector3.new(0, 12.6, 3.5), Vector3.new(4.6, 1.2, 0.5), teal)
		box(nil, "Cape", Vector3.new(0, 11.2, 3.65), Vector3.new(4.8, 1.6, 0.5), deep)
		box(nil, "Cape", Vector3.new(0, 9.6, 3.5), Vector3.new(4.2, 1.6, 0.5), teal)
		box(nil, "Cape", Vector3.new(0, 8, 3.65), Vector3.new(3.6, 1.6, 0.5), deep)
		box(nil, "CapeGold", Vector3.new(0, 12.1, 3.8), Vector3.new(2.4, 0.4, 0.3), gold)
		box(nil, "CapeGold", Vector3.new(0, 9, 3.85), Vector3.new(1.6, 0.4, 0.3), gold)
		box(nil, "CapeSpine", Vector3.new(0, 10.4, 3.4), Vector3.new(0.8, 4.4, 0.4), darkest)
		box(nil, "RumpWhite", Vector3.new(0, 6.3, 3.4), Vector3.new(3, 1.2, 0.5), WHITE)
		voxelScales(
			v,
			nil,
			"CapeFeather",
			"z",
			Vector3.new(0, 10.6, 4.15),
			Vector2.new(3.7, 4.6),
			Vector2.new(1.1, 0.9),
			{ teal, color, gold:Lerp(color, 0.55), deep },
			0.2
		)

		-- Cabeza: cráneo esmeralda con el reflejo dorado en la coronilla, cresta en escalones que se
		-- estrecha hacia atrás, ojo negro con su brillo y el pico amarillo corto y ganchudo.
		local head: { BasePart } = {}
		box(head, "Head", Vector3.new(0, 16.9, -0.6), Vector3.new(5.2, 4.4, 5), color)
		box(head, "Crown", Vector3.new(0, 19.3, -0.5), Vector3.new(4.4, 0.6, 4.2), gold)
		box(head, "Crest", Vector3.new(0, 20, -0.2), Vector3.new(3.4, 0.8, 3.6), teal)
		box(head, "Crest", Vector3.new(0, 20.8, 0.2), Vector3.new(2.4, 0.8, 2.8), color)
		box(head, "Crest", Vector3.new(0, 21.6, 0.7), Vector3.new(1.4, 0.8, 1.8), deep)
		box(head, "Crest", Vector3.new(0, 20.6, 2.1), Vector3.new(1.4, 0.6, 1.2), deep)
		box(head, "Nape", Vector3.new(0, 17, 2.05), Vector3.new(4.2, 3.6, 0.4), deep)
		for i, x in { -1.4, 0, 1.4 } do
			box(head, "CrestFeather", Vector3.new(x, 20.45, -0.4 + (i % 2) * 0.8), Vector3.new(0.5, 0.1, 2.4), gold)
		end
		for i, spec in { { -0.9, 1.6 }, { 0.9, 1.4 }, { 0, 2.2 } } do
			box(
				head,
				"CrestWisp",
				Vector3.new(spec[1], 21.8 + spec[2] / 2, 0.9 + i * 0.3),
				Vector3.new(0.5, spec[2], 0.5),
				if i == 3 then gold else teal
			)
			box(
				head,
				"CrestWisp",
				Vector3.new(spec[1], 21.8 + spec[2], 1.6 + i * 0.3),
				Vector3.new(0.5, 0.5, 0.9),
				deep
			)
		end
		box(head, "Throat", Vector3.new(0, 15.1, -1.9), Vector3.new(3.6, 1.2, 1.4), teal)
		for _, side in { -1, 1 } do
			box(head, "EyeRing", Vector3.new(side * 2.62, 17.5, -1.8), Vector3.new(0.1, 1.9, 1.9), darkest)
			box(
				head,
				"Iris",
				Vector3.new(side * 2.69, 17.5, -1.8),
				Vector3.new(0.1, 1.5, 1.5),
				Color3.fromRGB(95, 55, 30)
			)
			box(head, "Eye", Vector3.new(side * 2.76, 17.5, -1.8), Vector3.new(0.1, 1, 1), BLACK)
			box(head, "Glint", Vector3.new(side * 2.84, 17.8, -2.05), Vector3.new(0.1, 0.4, 0.4), WHITE)
			box(head, "Cheek", Vector3.new(side * 2.62, 16.2, -2.6), Vector3.new(0.1, 1.2, 1.4), teal)
			box(
				head,
				"HeadFeather",
				Vector3.new(side * 2.65, 18.7, -0.6),
				Vector3.new(0.1, 0.3, 2.4),
				gold:Lerp(color, 0.4)
			)
		end
		box(head, "Beak", Vector3.new(0, 16.6, -3.8), Vector3.new(2, 1.8, 1.8), yellow)
		box(head, "BeakHook", Vector3.new(0, 15.9, -4.55), Vector3.new(1.4, 1.2, 0.7), yellow:Lerp(BLACK, 0.2))
		box(head, "LowerBeak", Vector3.new(0, 15.4, -3.6), Vector3.new(1.6, 0.6, 1.4), yellow:Lerp(BLACK, 0.3))
		box(head, "BeakShine", Vector3.new(0, 17.55, -3.8), Vector3.new(1.2, 0.1, 1.2), yellow:Lerp(WHITE, 0.4))
		v.swing(head, Vector3.new(0, 16, -0.5), Vector3.xAxis, 0.1, 3, 0, false, nil, "Head")

		-- Alas abiertas: el borde de ataque dorado, las cobertoras esmeralda y turquesa en filas, las remeras que
		-- se alargan y se oscurecen hacia la punta con el borde de atrás en flecos, y la franja pálida.
		for _, side in { -1, 1 } do
			voxelWing(v, side, Vector3.new(side * 2.4, 12.6, 0.4), {
				{ center = Vector3.new(3, 0.1, -0.2), size = Vector3.new(6, 1.2, 4.4), color = color },
				{ center = Vector3.new(7.6, 0, 0.2), size = Vector3.new(4, 1.1, 4), color = teal },
				{ center = Vector3.new(4.8, 0.45, -2.2), size = Vector3.new(8.4, 0.4, 0.5), color = gold },
				{ center = Vector3.new(11.6, 0.4, -1.2), size = Vector3.new(4, 0.4, 0.5), color = gold },
				{ center = Vector3.new(3.6, -0.1, 3.8), size = Vector3.new(6.6, 0.9, 3), color = deep },
				{ center = Vector3.new(6, -0.2, 2.2), size = Vector3.new(5, 0.9, 0.7), color = pale },
				{ center = Vector3.new(4, -0.2, 6.2), size = Vector3.new(5.6, 0.8, 2.2), color = darkest },
				{ center = Vector3.new(9.6, -0.2, 3.8), size = Vector3.new(6, 0.8, 5), color = deep },
				{ center = Vector3.new(14, -0.2, 3.6), size = Vector3.new(4, 0.7, 5.2), color = darkest },
				{ center = Vector3.new(17, -0.3, 3), size = Vector3.new(2.2, 0.6, 3.8), color = darkest },
				{ center = Vector3.new(9.4, -0.3, 6.9), size = Vector3.new(2.4, 0.6, 1.4), color = darkest },
				{ center = Vector3.new(13, -0.3, 7), size = Vector3.new(2, 0.6, 1.4), color = darkest },
				{ center = Vector3.new(6.2, -0.3, 7.2), size = Vector3.new(1.8, 0.6, 1.4), color = deep },
				{ center = Vector3.new(16.2, -0.3, 6.4), size = Vector3.new(1.6, 0.5, 1.6), color = darkest },
				{ center = Vector3.new(18.6, -0.3, 4.4), size = Vector3.new(1.6, 0.5, 2.6), color = darkest },
				{ center = Vector3.new(19.6, -0.3, 2.6), size = Vector3.new(1.2, 0.5, 1.8), color = darkest },
				{ center = Vector3.new(14, -0.1, 0.4), size = Vector3.new(4, 0.6, 1.8), color = teal },
				{
					center = Vector3.new(1.6, 0.8, -0.2),
					size = Vector3.new(2.2, 0.25, 4),
					color = teal:Lerp(gold, 0.3),
				},
				{ center = Vector3.new(3.6, 0.8, -0.2), size = Vector3.new(1.8, 0.25, 4), color = deep },
				{ center = Vector3.new(5.4, 0.8, -0.2), size = Vector3.new(1.8, 0.25, 4), color = color },
				{
					center = Vector3.new(7, 0.65, 0.2),
					size = Vector3.new(1.4, 0.25, 3.6),
					color = gold:Lerp(teal, 0.5),
				},
				{ center = Vector3.new(8.6, 0.65, 0.2), size = Vector3.new(1.4, 0.25, 3.6), color = teal },
				{ center = Vector3.new(11.8, -0.55, 3.8), size = Vector3.new(0.25, 0.1, 4.6), color = BLACK },
				{ center = Vector3.new(15.2, -0.6, 3.6), size = Vector3.new(0.25, 0.1, 4.6), color = BLACK },
			}, 0.7, 12)
		end

		-- Cola: la base blanca por debajo con la punta oscura, y dos plumas larguísimas que cuelgan hacia
		-- atrás y se enroscan hacia arriba en la punta (en escalones de bloques, no inclinadas: así entran en la
		-- malla).
		local tailParts: { BasePart } = {}
		voxelStairs(
			v,
			tailParts,
			"TailCovert",
			Vector3.new(0, 7.2, 3.4),
			Vector3.new(0, 5.2, 9),
			Vector2.new(3.4, 1),
			color,
			1.6
		)
		box(tailParts, "TailWhite", Vector3.new(0, 4.9, 7), Vector3.new(2.8, 0.5, 5), WHITE)
		box(tailParts, "TailDark", Vector3.new(0, 5.1, 10.6), Vector3.new(2.2, 0.5, 2.2), darkest)
		-- Cada pluma larga sigue una curva: sale de la cola, cuelga hacia atrás, se enrosca hacia arriba y acaba en una horquilla.
		-- A lo largo lleva el estandarte (las barbas, láminas finas a cada lado) en dos tonos.
		for _, side in { -1, 1 } do
			local path = {
				Vector3.new(side * 0.9, 6.6, 3.6),
				Vector3.new(side * 1.0, 4, 12),
				Vector3.new(side * 1.4, 2.4, 22),
				Vector3.new(side * 2.2, 3.4, 29),
			}
			local colors = { color, teal, deep }
			for i = 1, 3 do
				voxelStairs(v, tailParts, "Streamer", path[i], path[i + 1], Vector2.new(0.8, 0.8), colors[i], 2.2)
			end
			local function onPath(z: number): Vector3
				for i = 1, 3 do
					local a, b = path[i], path[i + 1]
					if z <= b.Z or i == 3 then
						local t = math.clamp((z - a.Z) / (b.Z - a.Z), 0, 1)
						return a:Lerp(b, t)
					end
				end
				return path[4]
			end
			for step = 0, 9 do
				local z = 9 + step * 2.2
				local p = onPath(z)
				local shade = if step % 2 == 0 then gold:Lerp(color, 0.45) else teal
				local reach = 1.4 - math.abs(step - 4) * 0.12
				v.box(
					tailParts,
					"Vane",
					p + Vector3.new(side * (0.4 + reach / 2), 0, 0),
					Vector3.new(reach, 0.25, 1.4),
					shade
				)
				v.box(
					tailParts,
					"Vane",
					p - Vector3.new(side * (0.4 + reach / 2), 0, 0),
					Vector3.new(reach, 0.25, 1.4),
					shade:Lerp(deep, 0.35)
				)
			end
			-- La punta se bifurca en dos hebras que se separan, con las puntas oscuras.
			for _, fork in { -1, 1 } do
				local tip = path[4] + Vector3.new(fork * 1.2, 1.2, 4.4)
				voxelStairs(v, tailParts, "Fork", path[4], tip, Vector2.new(0.6, 0.6), deep, 1.6)
				v.box(tailParts, "ForkTip", tip + Vector3.new(0, 0.3, 0.5), Vector3.new(0.6, 0.6, 1), darkest)
			end
		end
		v.swing(tailParts, Vector3.new(0, 7.2, 3.6), Vector3.xAxis, 0.18, 5, 1, false, nil, "Tail")
		rig.family = "Bird"
		return "Fly"
	end,

	-- Perezoso voxel (docs/img/Perezoso.jfif): a cuatro patas, con los brazos de delante muy largos
	-- y las garras claras en gancho; pelo gris pardo desgreñado en escalones con una mancha clara en
	-- el lomo, cara crema con el antifaz oscuro y una sonrisa permanente.
	Perezoso = function(rig, color)
		local v = voxelKit(rig, Vector3.new(0, 10, 0))
		local box = v.box
		local fur = color:Lerp(Color3.fromRGB(85, 80, 76), 0.75)
		local shag = fur:Lerp(BLACK, 0.15)
		local light = fur:Lerp(WHITE, 0.25)
		-- Los brazos inclinados reciben más luz por arriba y salían casi blancos: un poco más oscuros.
		local limb = fur:Lerp(BLACK, 0.15)
		local face = Color3.fromRGB(215, 195, 160)
		local dark = Color3.fromRGB(55, 42, 35)
		local claw = Color3.fromRGB(215, 205, 175)
		local clawTip = claw:Lerp(dark, 0.35)

		-- Tronco: el pecho más alto que la grupa (los brazos son más largos que las patas), con
		-- escalones de pelo encima y la mancha clara del lomo en rombo.
		box(nil, "Body", Vector3.new(0, 13.5, -2), Vector3.new(10, 7, 7), fur)
		box(nil, "Rump", Vector3.new(0, 12, 4.5), Vector3.new(9.6, 6.6, 6.5), fur)
		box(nil, "Shag", Vector3.new(0, 17.4, -1.2), Vector3.new(8, 0.8, 7.2), shag)
		box(nil, "Shag", Vector3.new(0, 15.7, 4.4), Vector3.new(7.6, 0.8, 6), shag)
		box(nil, "BackPatch", Vector3.new(0, 17.9, -0.8), Vector3.new(2.6, 0.2, 5), light)
		box(nil, "BackPatch", Vector3.new(0, 17.9, -1), Vector3.new(4.4, 0.2, 2.6), light)
		box(nil, "BackPatch", Vector3.new(0, 16.2, 3.4), Vector3.new(2.4, 0.2, 2.4), light)
		-- Flecos de pelo que cuelgan por los costados y la grupa, alternando tonos.
		for i, z in { -4.5, -2, 0.5, 3, 5.6 } do
			for _, side in { -1, 1 } do
				local x = if z < 1 then 5.15 else 4.95
				box(
					nil,
					"Fringe",
					Vector3.new(side * x, if z < 1 then 10.2 else 8.8, z),
					Vector3.new(0.4, 2.4, 2),
					if i % 2 == 0 then shag else light:Lerp(fur, 0.5)
				)
				box(
					nil,
					"Streak",
					Vector3.new(side * x, if z < 1 then 14.6 else 13.4, z + 0.5),
					Vector3.new(0.3, 1, 2.6),
					shag
				)
			end
		end
		box(nil, "Fringe", Vector3.new(0, 10, 7.95), Vector3.new(6, 2.4, 0.4), shag)
		voxelScales(
			v,
			nil,
			"Strand",
			"z",
			Vector3.new(0, 12.6, 7.85),
			Vector2.new(9, 5.4),
			Vector2.new(1, 1.3),
			{ shag, fur, light:Lerp(fur, 0.4) },
			0.15
		)
		voxelTopScales(
			v,
			nil,
			"Strand",
			Vector3.new(0, 16.15, 4.4),
			Vector2.new(7, 5.6),
			Vector2.new(0.9, 1.4),
			{ shag, fur, light:Lerp(fur, 0.4) },
			0.15
		)
		voxelTopScales(
			v,
			nil,
			"Strand",
			Vector3.new(0, 17.85, -1.2),
			Vector2.new(7, 6.4),
			Vector2.new(0.9, 1.4),
			{ shag, fur, light:Lerp(fur, 0.4) },
			0.12
		)
		box(nil, "Stub", Vector3.new(0, 12.4, 8), Vector3.new(1.6, 1.4, 0.6), shag)

		-- Mochila de carga (es la mascota de Carga): saco de lona con la solapa de cuero y sus
		-- hebillas, bolsillos, la manta enrollada y dos troncos atados encima, un racimo de plátanos
		-- colgando de un lado y una cantimplora del otro, y los tirantes por los hombros.
		local canvas = Color3.fromRGB(125, 100, 60)
		local pocket = canvas:Lerp(BLACK, 0.15)
		local leather = Color3.fromRGB(90, 55, 30)
		local brass = Color3.fromRGB(175, 150, 80)
		local wood = Color3.fromRGB(115, 80, 45)
		local cut = Color3.fromRGB(200, 160, 105)
		box(nil, "Pack", Vector3.new(0, 19.8, 1.6), Vector3.new(6.6, 4, 5.4), canvas)
		box(nil, "Pack", Vector3.new(0, 17, 3.6), Vector3.new(6.2, 1.8, 2.4), canvas)
		box(nil, "PackFlap", Vector3.new(0, 21.95, 1.4), Vector3.new(6.8, 0.3, 5), leather)
		box(nil, "PackFlap", Vector3.new(0, 20.8, 4.45), Vector3.new(6.8, 2.4, 0.3), leather)
		box(nil, "PackPocket", Vector3.new(0, 18.2, 4.55), Vector3.new(4.4, 2.2, 0.5), pocket)
		for _, side in { -1, 1 } do
			-- Correas verticales de la solapa con la hebilla abajo: dos hebillas a la misma altura sobre
			-- el bolsillo parecían una cara.
			box(nil, "FlapStrap", Vector3.new(side * 1.8, 19.4, 4.9), Vector3.new(0.6, 3.6, 0.2), leather)
			box(nil, "Buckle", Vector3.new(side * 1.8, 17.9, 5.05), Vector3.new(0.8, 0.6, 0.15), brass)
			box(nil, "PackPocket", Vector3.new(side * 3.45, 19.2, 2.4), Vector3.new(0.4, 2.6, 2.2), pocket)
			box(nil, "Strap", Vector3.new(side * 3.6, 17.95, -3.4), Vector3.new(1, 0.3, 4.8), leather)
			box(nil, "Strap", Vector3.new(side * 3.6, 14.4, -5.65), Vector3.new(1, 6.8, 0.3), leather)
		end
		-- Manta roja enrollada delante, con dos ataduras.
		box(nil, "Bedroll", Vector3.new(0, 22.9, -0.2), Vector3.new(7.6, 1.8, 1.8), Color3.fromRGB(150, 60, 45))
		for _, x in { -2.4, 2.4 } do
			box(nil, "Tie", Vector3.new(x, 22.9, -0.2), Vector3.new(0.4, 1.9, 1.9), leather)
		end
		-- Dos troncos de través detrás, con el corte claro y su anillo, atados con cuerda.
		for _, z in { 2.3, 3.8 } do
			box(nil, "Log", Vector3.new(0, 22.8, z), Vector3.new(8.8, 1.4, 1.4), wood)
			for _, side in { -1, 1 } do
				box(nil, "LogEnd", Vector3.new(side * 4.45, 22.8, z), Vector3.new(0.1, 1.2, 1.2), cut)
				box(nil, "LogRing", Vector3.new(side * 4.5, 22.8, z), Vector3.new(0.1, 0.5, 0.5), cut:Lerp(wood, 0.5))
			end
		end
		for _, x in { -1.5, 1.5 } do
			box(nil, "Rope", Vector3.new(x, 22.8, 3.05), Vector3.new(0.4, 1.6, 3.2), Color3.fromRGB(150, 135, 85))
		end
		-- Racimo de plátanos colgando a la derecha y cantimplora a la izquierda.
		box(nil, "BananaStem", Vector3.new(3.9, 20.5, -0.1), Vector3.new(0.4, 0.6, 0.4), Color3.fromRGB(70, 90, 40))
		for k = -1, 1 do
			local z = -0.1 + k * 0.55
			box(nil, "Banana", Vector3.new(3.95, 19.3, z), Vector3.new(0.6, 1.8, 0.5), Color3.fromRGB(240, 200, 50))
			box(nil, "BananaTip", Vector3.new(3.95, 18.25, z), Vector3.new(0.4, 0.3, 0.4), Color3.fromRGB(70, 50, 30))
		end
		box(nil, "Canteen", Vector3.new(-3.9, 19.3, 0), Vector3.new(0.6, 1.8, 1.6), Color3.fromRGB(95, 120, 90))
		box(nil, "CanteenCap", Vector3.new(-3.9, 20.35, 0), Vector3.new(0.4, 0.3, 0.4), cut)

		-- Cabeza pequeña con la cara crema, el antifaz que va de los ojos hacia atrás, nariz oscura y
		-- sonrisa. Ladea despacio, como buen perezoso.
		local head: { BasePart } = {}
		box(head, "Head", Vector3.new(0, 12.6, -7.5), Vector3.new(7, 6.4, 4.4), fur)
		box(head, "HairCap", Vector3.new(0, 15.9, -7.3), Vector3.new(6.2, 0.8, 4), shag)
		box(head, "Face", Vector3.new(0, 12.2, -9.85), Vector3.new(5.6, 4.8, 0.4), face)
		box(head, "Fringe", Vector3.new(0, 14.75, -9.9), Vector3.new(6.4, 0.8, 0.6), fur)
		for _, side in { -1, 1 } do
			box(head, "Mask", Vector3.new(side * 1.7, 12.9, -10.1), Vector3.new(2.2, 1.1, 0.2), dark)
			box(head, "Mask", Vector3.new(side * 3.6, 12.9, -8.6), Vector3.new(0.2, 1.1, 2.6), dark)
			box(head, "Eye", Vector3.new(side * 1.6, 12.9, -10.25), Vector3.new(0.9, 0.8, 0.1), BLACK)
			box(head, "Glint", Vector3.new(side * 1.4, 13.1, -10.32), Vector3.new(0.3, 0.3, 0.05), WHITE)
			box(head, "Smile", Vector3.new(side * 1.25, 10.75, -10.1), Vector3.new(0.4, 0.6, 0.2), dark)
		end
		box(head, "Nose", Vector3.new(0, 11.6, -10.2), Vector3.new(1.6, 1, 0.3), dark)
		box(head, "Smile", Vector3.new(0, 10.5, -10.1), Vector3.new(2.2, 0.3, 0.2), dark)
		voxelTopScales(
			v,
			head,
			"Strand",
			Vector3.new(0, 16.35, -7.3),
			Vector2.new(5.6, 3.6),
			Vector2.new(0.9, 1.2),
			{ shag, fur, light:Lerp(fur, 0.4) },
			0.15
		)
		for _, side in { -1, 1 } do
			box(head, "CheekFur", Vector3.new(side * 3.6, 12, -7.8), Vector3.new(0.3, 2.6, 2.4), light:Lerp(fur, 0.5))
			box(
				head,
				"EyeShade",
				Vector3.new(side * 1.6, 12.9, -10.15),
				Vector3.new(1.4, 1.3, 0.12),
				dark:Lerp(BLACK, 0.3)
			)
		end
		box(head, "NoseShine", Vector3.new(0, 11.95, -10.38), Vector3.new(0.8, 0.2, 0.1), dark:Lerp(WHITE, 0.4))
		v.swing(head, Vector3.new(0, 12.6, -5.5), Vector3.zAxis, 0.15, 0.6, 0, false, nil, "Head")

		-- Garra en gancho: un bloque hacia delante y la punta que baja.
		local function hook(list: { BasePart }, base: Vector3, length: number)
			box(list, "Claw", base + Vector3.new(0, 0, -length / 2), Vector3.new(0.6, 0.6, length), claw)
			box(list, "ClawTip", base + Vector3.new(0, -0.6, -length + 0.3), Vector3.new(0.6, 1.2, 0.6), clawTip)
		end
		for _, side in { -1, 1 } do
			-- Brazo largo que baja hacia delante hasta la mano, con un mechón en el codo.
			local arm: { BasePart } = {}
			voxelLimb(
				v,
				arm,
				"UpperArm",
				Vector3.new(side * 5.6, 14.5, -3),
				Vector3.new(side * 6, 7.5, -8),
				3.2,
				limb,
				1.1
			)
			voxelLimb(
				v,
				arm,
				"Forearm",
				Vector3.new(side * 6, 7.8, -8),
				Vector3.new(side * 6.1, 1.6, -12.6),
				3,
				limb,
				1.1
			)
			for k, y in { 12.5, 10.5, 8.5, 5.5, 3.5 } do
				box(
					arm,
					"ArmFur",
					Vector3.new(side * 7.65, y, -3.4 - (14.5 - y) * 0.7),
					Vector3.new(0.3, 1.2, 2.2),
					if k % 2 == 0 then shag else light:Lerp(fur, 0.5)
				)
			end
			box(arm, "ElbowShag", Vector3.new(side * 6.2, 7.8, -7.2), Vector3.new(3.2, 2.6, 3), shag)
			box(arm, "Hand", Vector3.new(side * 6.1, 1.1, -13), Vector3.new(2.8, 1.6, 2.8), shag)
			for k = -1, 1 do
				hook(arm, Vector3.new(side * 6.1 + k * 0.85, 1.2, -14.2), 2)
			end
			v.swing(
				arm,
				Vector3.new(side * 5.4, 14, -3),
				Vector3.xAxis,
				0.5,
				4,
				if side < 0 then 0 else math.pi,
				true,
				nil,
				if side < 0 then "FL" else "FR"
			)

			-- Pata de atrás más corta, con tres garras.
			local leg: { BasePart } = {}
			box(leg, "Thigh", Vector3.new(side * 4.8, 8.6, 5.4), Vector3.new(3, 4.4, 3.8), fur)
			box(leg, "Shin", Vector3.new(side * 5, 4.2, 5.2), Vector3.new(2.6, 5, 2.6), fur)
			box(leg, "Foot", Vector3.new(side * 5, 1, 4.6), Vector3.new(2.6, 1.6, 3), dark)
			for k = -1, 1 do
				hook(leg, Vector3.new(side * 5 + k * 0.8, 1.1, 3.2), 1.4)
			end
			v.swing(
				leg,
				Vector3.new(side * 4, 10, 5.5),
				Vector3.xAxis,
				0.4,
				4,
				if side < 0 then math.pi else 0,
				true,
				nil,
				if side < 0 then "BL" else "BR"
			)
		end
		return "Walk"
	end,

	-- Capibara voxel (docs/img/Capibara Voxel.jfif): un roedor grande de cuerpo largo y bajo (casi
	-- 2,3 veces más largo que alto a la cruz), con la grupa un poco más alta que los hombros, el lomo
	-- claro en escalones sobre el pelaje oscuro y la barriga pálida. Cabeza grande y cuadrada con el
	-- hocico romo y la nariz casi negra con la glándula encima, fosas, labio partido con los dos
	-- incisivos, ojos pequeños altos y atrás bajo una ceja, orejitas redondas oscuras y bigotes. Patas
	-- cortas: las de delante finas con cuatro dedos y las de atrás más gruesas con tres. Mira hacia -Z.
	Capibara = function(rig, color)
		local v = voxelKit(rig, Vector3.new(0, 10, 0))
		local box = v.box
		local fur = color
		local dark = fur:Lerp(Color3.fromRGB(38, 22, 16), 0.55)
		local light = fur:Lerp(Color3.fromRGB(235, 175, 105), 0.5)
		local belly = Color3.fromRGB(205, 165, 110)
		local nose = Color3.fromRGB(42, 28, 26)
		local leg = fur:Lerp(dark, 0.3)
		local warm = fur:Lerp(Color3.fromRGB(190, 120, 70), 0.35) -- mechón claro del pelaje
		local deep = fur:Lerp(Color3.fromRGB(30, 16, 12), 0.35) -- mechón oscuro
		-- Tono de un mechón según su número: reparte los cuatro tonos sin que se vea el patrón.
		local function strand(i: number): Color3
			local k = i % 4
			return if k == 0 then warm elseif k == 1 then deep elseif k == 2 then light else fur:Lerp(dark, 0.2)
		end

		-- Tronco: pecho, lomo y una grupa más alta con el muslo marcado. Hombro y anca salen del costado
		-- (silueta); el lomo claro va en escalones con manchas oscuras, y el pelo fino va pintado encima.
		box(nil, "Body", Vector3.new(0, 7.2, 0), Vector3.new(8, 6.4, 13), fur)
		box(nil, "Chest", Vector3.new(0, 7, -5.8), Vector3.new(7.6, 6, 2.6), fur)
		-- Grupa redondeada: baja en tres escalones que se estrechan hacia el rabo (la cadera del capibara cae
		-- por detrás del lomo en vez de acabar cuadrada), cada uno con su tapa clara.
		box(nil, "Rump", Vector3.new(0, 7.2, 7.25), Vector3.new(7.6, 5.6, 1.5), fur)
		box(nil, "Rump", Vector3.new(0, 6.6, 8.6), Vector3.new(6.6, 4.4, 1.2), fur)
		box(nil, "Rump", Vector3.new(0, 6, 9.6), Vector3.new(5.2, 2.8, 0.8), fur:Lerp(dark, 0.15))
		box(nil, "Belly", Vector3.new(0, 4.1, 1.5), Vector3.new(6, 0.8, 12), belly)
		box(nil, "Back", Vector3.new(0, 10.6, 0.45), Vector3.new(6.4, 0.8, 11.9), light)
		box(nil, "Back", Vector3.new(0, 11.1, 2.95), Vector3.new(4.2, 0.6, 6.9), light:Lerp(WHITE, 0.12))
		box(nil, "Back", Vector3.new(0, 11.0, -3.2), Vector3.new(3.6, 0.4, 3), light:Lerp(dark, 0.15))
		box(nil, "RumpCap", Vector3.new(0, 10.15, 7.25), Vector3.new(6.4, 0.3, 1.5), light:Lerp(fur, 0.2))
		box(nil, "RumpCap", Vector3.new(0, 8.95, 8.6), Vector3.new(5.4, 0.3, 1.2), light:Lerp(fur, 0.35))
		box(nil, "RumpCap", Vector3.new(0, 7.55, 9.6), Vector3.new(4.2, 0.3, 0.8), light:Lerp(fur, 0.5))
		box(nil, "Patch", Vector3.new(1.8, 10.4, 7.2), Vector3.new(2, 0.2, 1.2), dark)
		box(nil, "Patch", Vector3.new(-1.8, 11.4, 4.4), Vector3.new(2, 0.4, 2.4), dark)
		box(nil, "Patch", Vector3.new(1.6, 11.4, 1), Vector3.new(2.2, 0.4, 2), dark)
		box(nil, "Patch", Vector3.new(-1.4, 10.9, -3.4), Vector3.new(2.4, 0.4, 2.6), dark)
		-- Silueta: el hombro (pecho ancho) y el anca (grupa redonda) sobresalen del costado, y la panza cuelga.
		for _, side in { -1, 1 } do
			box(nil, "Shoulder", Vector3.new(side * 4.3, 7.4, -4.6), Vector3.new(0.6, 4.4, 3), fur:Lerp(light, 0.15))
			box(nil, "Haunch", Vector3.new(side * 4.2, 6.6, 7.2), Vector3.new(0.8, 4.4, 2.4), fur:Lerp(dark, 0.1))
			box(nil, "Sag", Vector3.new(side * 2.6, 3.6, 1.5), Vector3.new(1.4, 0.6, 9), belly:Lerp(fur, 0.35))
		end
		-- Mechones de los costados: cada uno en el tono que toca, pegados al hombro, al anca o al flanco.
		for i, z in { -4.5, -0.5, 3.5, 7.2 } do
			for _, side in { -1, 1 } do
				local outer = if z < -3 or z > 6 then 4.6 else 4.0
				local depth = if z > 6 then 2.4 else 3
				box(
					nil,
					"Tuft",
					Vector3.new(side * (outer + 0.15), 7.6, z),
					Vector3.new(0.3, 3.4, depth),
					strand(i + 1)
				)
				if outer == 4 then
					box(nil, "Tuft", Vector3.new(side * 4.15, 5.2, z + 1.5), Vector3.new(0.3, 1.4, 2), dark)
				end
				box(
					nil,
					"Tuft",
					Vector3.new(side * (outer + 0.35), 8.9, z + 0.4),
					Vector3.new(0.1, 1.0, depth - 1.6),
					strand(i + 3)
				)
				box(
					nil,
					"Tuft",
					Vector3.new(side * (outer + 0.35), 6.2, z - 0.5),
					Vector3.new(0.1, 1.0, depth - 1.8),
					strand(i + 2)
				)
			end
		end
		-- Pelo del lomo: mechones finos sueltos sobre las dos capas claras (pintados, casi sin coste).
		for i = 1, 19 do
			local z = -4.4 + (i - 1) * 0.58
			local x = (((i * 7) % 11) - 5) * 0.55
			local onTop = math.abs(x) < 2 and z > -0.4
			local y = if onTop then 11.5 else 11.1
			if z > -4.7 and z < -1.7 and math.abs(x) < 1.8 then
				y = 11.25
			end
			box(nil, "Hair", Vector3.new(x, y, z), Vector3.new(0.35, 0.1, 1.1), strand(i))
		end
		-- Y en la grupa, siguiendo sus escalones.
		for i, spec in
			{ { -1.5, 10.4, 7.2 }, { 0.8, 10.4, 6.9 }, { 1.4, 9.1, 8.6 }, { -1.2, 9.1, 8.5 }, { 0.2, 7.7, 9.6 } }
		do
			box(nil, "Hair", Vector3.new(spec[1], spec[2], spec[3]), Vector3.new(0.35, 0.1, 0.8), strand(i + 1))
		end
		-- Grupa vista desde atrás (lo que más ve el jugador): flequillo del trasero en tres tonos y la rabadilla.
		for i, x in { -2.4, -1.4, -0.4, 0.4, 1.4, 2.4 } do
			local h = 2.4 - (i % 3) * 0.5
			box(nil, "Fringe", Vector3.new(x, 7.4 - h / 2, 10.15), Vector3.new(0.9, h, 0.3), strand(i))
		end
		box(nil, "Tail", Vector3.new(0, 6.9, 10.6), Vector3.new(1.2, 1.2, 0.6), nose)
		box(nil, "TailTip", Vector3.new(0, 6.6, 11.05), Vector3.new(0.8, 0.8, 0.3), nose:Lerp(fur, 0.3))

		-- Cuello corto y grueso, y la cabeza grande: cráneo cuadrado, hocico romo que cae en la nariz
		-- oscura, la barbilla pálida, los ojos pequeños altos y atrás, ceja, orejitas y bigotes.
		box(nil, "Neck", Vector3.new(0, 8.4, -7.8), Vector3.new(6.8, 5.4, 2.2), fur)
		for i, y in { 6.4, 7.4, 8.4, 9.4 } do
			for _, side in { -1, 1 } do
				box(
					nil,
					"NeckHair",
					Vector3.new(side * 3.55, y, -7.8 + (i % 2) * 0.4),
					Vector3.new(0.3, 1, 1.6),
					strand(i)
				)
			end
		end
		local head: { BasePart } = {}
		box(head, "Head", Vector3.new(0, 8.6, -10.8), Vector3.new(6.6, 5.8, 5.4), fur)
		box(head, "Forehead", Vector3.new(0, 11.6, -10.6), Vector3.new(5.4, 0.4, 4.4), light)
		box(head, "Snout", Vector3.new(0, 8, -14.4), Vector3.new(5.8, 4.8, 2.2), fur:Lerp(dark, 0.35))
		box(head, "NosePad", Vector3.new(0, 8.4, -15.7), Vector3.new(5.6, 4, 0.4), nose)
		-- Arco del hocico: la frente baja en escalones hasta la nariz en vez de cortarse en seco.
		box(head, "Bridge", Vector3.new(0, 10.9, -13.3), Vector3.new(5.4, 0.8, 1.8), fur)
		box(head, "Bridge", Vector3.new(0, 10.35, -15.1), Vector3.new(4.8, 0.5, 1), fur:Lerp(dark, 0.35))
		box(head, "Gland", Vector3.new(0, 10.6, -14.4), Vector3.new(2.6, 0.4, 2.8), dark)
		box(head, "Chin", Vector3.new(0, 5.5, -14.2), Vector3.new(4, 0.9, 2.6), belly)
		box(head, "Lip", Vector3.new(0, 6.5, -15.35), Vector3.new(4.6, 0.8, 0.8), nose:Lerp(fur, 0.25))
		box(head, "Philtrum", Vector3.new(0, 7, -15.95), Vector3.new(0.2, 1.6, 0.2), BLACK)
		box(head, "Mouth", Vector3.new(0, 6.3, -15.95), Vector3.new(4, 0.25, 0.2), BLACK)
		box(head, "NoseShine", Vector3.new(0, 9.9, -15.95), Vector3.new(4, 0.3, 0.1), nose:Lerp(WHITE, 0.2))
		-- Pelo de la cabeza: mechones sobre la frente y la nuca.
		for i, x in { -2.2, -1.1, 0, 1.1, 2.2 } do
			box(head, "HeadHair", Vector3.new(x, 11.85, -9.6 - (i % 2) * 1.2), Vector3.new(0.3, 0.1, 1.4), strand(i))
		end
		for _, side in { -1, 1 } do
			-- Carrillo: una pieza gruesa (la mejilla redonda) con el pelo claro pintado encima.
			box(head, "Jowl", Vector3.new(side * 3.55, 6.9, -12.6), Vector3.new(0.5, 2.6, 3.4), belly:Lerp(fur, 0.2))
			box(head, "Cheek", Vector3.new(side * 3.85, 7.0, -12.5), Vector3.new(0.1, 2.2, 2.6), belly)
			box(head, "CheekHair", Vector3.new(side * 3.85, 6.3, -11.5), Vector3.new(0.1, 0.7, 1.2), strand(2))
			box(head, "Nostril", Vector3.new(side * 1.5, 9.3, -15.95), Vector3.new(0.9, 1, 0.2), BLACK)
			box(
				head,
				"Incisor",
				Vector3.new(side * 0.5, 5.8, -15.95),
				Vector3.new(0.7, 0.5, 0.2),
				Color3.fromRGB(240, 225, 180)
			)
			box(head, "Brow", Vector3.new(side * 3.3, 10.7, -11.4), Vector3.new(0.3, 0.4, 1.8), dark)
			-- Ojo con capas: cuenca oscura, iris ámbar, pupila, brillo y párpado de arriba y de abajo.
			box(head, "EyeSocket", Vector3.new(side * 3.36, 10, -11.4), Vector3.new(0.12, 1.3, 1.5), deep)
			box(
				head,
				"Iris",
				Vector3.new(side * 3.43, 10, -11.4),
				Vector3.new(0.1, 1, 1.1),
				Color3.fromRGB(150, 85, 30)
			)
			box(head, "Eye", Vector3.new(side * 3.49, 10, -11.4), Vector3.new(0.1, 0.8, 0.6), BLACK)
			box(head, "Glint", Vector3.new(side * 3.56, 10.3, -11.65), Vector3.new(0.1, 0.3, 0.3), WHITE)
			box(head, "Lid", Vector3.new(side * 3.49, 10.55, -11.4), Vector3.new(0.1, 0.25, 1.3), dark)
			box(head, "LowLid", Vector3.new(side * 3.49, 9.4, -11.4), Vector3.new(0.1, 0.2, 1.1), warm)
			-- Oreja: dos escalones (la oreja redonda) con el interior rosado y borde de pelo oscuro.
			box(head, "Ear", Vector3.new(side * 2.4, 12, -9.4), Vector3.new(1.4, 1.4, 1.2), dark)
			box(head, "EarTop", Vector3.new(side * 2.4, 12.85, -9.4), Vector3.new(1, 0.4, 0.9), dark)
			box(
				head,
				"EarInner",
				Vector3.new(side * 2.4, 12.1, -10.05),
				Vector3.new(0.9, 0.9, 0.2),
				Color3.fromRGB(150, 95, 80)
			)
			for _, y in { 7.3, 7.9 } do
				box(head, "Whisker", Vector3.new(side * 4.1, y, -14.8), Vector3.new(1.6, 0.15, 0.15), BLACK)
			end
		end
		v.swing(head, Vector3.new(0, 8.6, -8), Vector3.zAxis, 0.08, 0.7, 0, false, nil, "Head")

		-- Patas cortas: las de delante finas con cuatro dedos y las de atrás más gruesas con tres; cada una
		-- con su pelo en bandas, rodilla marcada y uñas.
		for _, side in { -1, 1 } do
			for _, hind in { false, true } do
				local z = if hind then 7.2 else -5.2
				local x = side * (if hind then 3.3 else 3)
				local part: { BasePart } = {}
				if hind then
					box(part, "Thigh", Vector3.new(x, 3.1, z), Vector3.new(3, 4.6, 3.6), leg)
					box(part, "Knee", Vector3.new(x, 2.3, z - 2.1), Vector3.new(2.2, 1.4, 0.6), leg:Lerp(dark, 0.3))
					for i, y in { 4.2, 3.2, 2.2 } do
						box(
							part,
							"LegHair",
							Vector3.new(x + side * 1.65, y, z + 0.2),
							Vector3.new(0.3, 0.8, 2.6),
							strand(i)
						)
					end
				else
					box(part, "Leg", Vector3.new(x, 2.7, z), Vector3.new(2.4, 3.8, 2.6), leg)
					box(part, "Knee", Vector3.new(x, 2.5, z - 1.6), Vector3.new(1.8, 1.2, 0.5), leg:Lerp(dark, 0.3))
					for i, y in { 3.8, 2.8, 1.9 } do
						box(part, "LegHair", Vector3.new(x + side * 1.35, y, z), Vector3.new(0.3, 0.7, 1.8), strand(i))
					end
				end
				box(part, "Foot", Vector3.new(x, 0.9, z - 0.4), Vector3.new(2.6, 1.4, 3.4), dark)
				local toes = if hind then { -0.8, 0, 0.8 } else { -0.9, -0.3, 0.3, 0.9 }
				for _, dx in toes do
					box(part, "Toe", Vector3.new(x + dx, 0.7, z - 2.3), Vector3.new(0.5, 0.9, 0.6), BLACK)
					box(
						part,
						"Nail",
						Vector3.new(x + dx, 0.45, z - 2.7),
						Vector3.new(0.4, 0.3, 0.2),
						nose:Lerp(WHITE, 0.2)
					)
				end
				local phase = if (side < 0) == hind then math.pi else 0
				local bone = (if hind then "B" else "F") .. (if side < 0 then "L" else "R")
				v.swing(part, Vector3.new(x, 5, z), Vector3.xAxis, 0.45, 4, phase, true, nil, bone)
			end
		end
		return "Walk"
	end,

	-- Mono X-7 voxel: la mascota legendaria, con más capas de detalle que las demás. Chimpancé del
	-- laboratorio de pelo azul eléctrico, encorvado sobre los nudillos (pecho alto, grupa baja y
	-- brazos largos), con musculatura en bloques y cicatrices cosidas. Casco de buzo oxidado con
	-- visor de espejo en cúpula, remaches y discos en las sienes; antena de anillos con la punta que
	-- brilla; mochila con el vial de suero encendido y "X-7" en la espalda (lo que más ve el
	-- jugador), mangueras anilladas y grilletes del laboratorio con su luz.
	MonoX7 = function(rig, color)
		local v = voxelKit(rig, Vector3.new(0, 10, 0))
		local box = v.box
		local fur = Color3.fromRGB(30, 95, 195)
		local furLight = fur:Lerp(Color3.fromRGB(130, 205, 255), 0.4)
		local furDark = fur:Lerp(BLACK, 0.3)
		local muscle = fur:Lerp(WHITE, 0.16)
		local hands = Color3.fromRGB(80, 68, 76)
		local scar = Color3.fromRGB(195, 120, 120)
		local stitch = Color3.fromRGB(70, 30, 40)
		local shell = Color3.fromRGB(195, 180, 148)
		local rust = Color3.fromRGB(170, 85, 38)
		local copper = Color3.fromRGB(185, 115, 65)
		local metal = Color3.fromRGB(95, 100, 112)
		local hose = Color3.fromRGB(55, 58, 68)
		local visorColor = Color3.fromRGB(20, 30, 60)
		local crest = shell:Lerp(metal, 0.35)

		local function neon(part: BasePart, transparency: number?): BasePart
			part.Material = Enum.Material.Neon
			part.Transparency = transparency or 0
			return part
		end
		-- Cicatriz cosida en una cara de lado (X = "x"): tira rosada a lo largo, la costura oscura
		-- encima y tres puntadas que la cruzan y asoman por arriba y por abajo. Un parche ancho con
		-- rayas parecía una ventana con barrotes.
		local function scarStrip(list: { BasePart }?, center: Vector3, length: number)
			local out = Vector3.new(math.sign(center.X) * 0.12, 0, 0)
			box(list, "Scar", center, Vector3.new(0.2, 1, length), scar)
			box(list, "Stitch", center + out, Vector3.new(0.1, 0.2, length * 0.85), stitch)
			for k = -1, 1 do
				box(
					list,
					"Stitch",
					center + out + Vector3.new(0, 0, k * length * 0.3),
					Vector3.new(0.1, 1.4, 0.25),
					stitch
				)
			end
		end

		-- Tronco encorvado y musculoso en escalones: pecho ancho y alto delante, lomo y grupa que bajan
		-- hacia atrás (cintura más estrecha que el pecho) y la joroba de los hombros con los trapecios
		-- que suben hacia el casco. Los músculos sobresalen 0,3–0,6 celdas con un tono ~10 % más claro
		-- y una raya oscura que los separa: más claros parecían rodilleras.
		local shadow = fur:Lerp(BLACK, 0.18)
		box(nil, "Body", Vector3.new(0, 13, -3), Vector3.new(12.6, 8, 6), fur)
		box(nil, "Hump", Vector3.new(0, 17.6, -2), Vector3.new(9.4, 1.2, 5), fur)
		box(nil, "Hump", Vector3.new(0, 18.6, -1.5), Vector3.new(6, 0.8, 3.6), furDark)
		box(nil, "Back", Vector3.new(0, 11.5, 2), Vector3.new(10, 7, 5), fur)
		box(nil, "Rump", Vector3.new(0, 9.5, 5.5), Vector3.new(9.4, 6, 4), fur)
		box(nil, "Belly", Vector3.new(0, 7.6, -3.4), Vector3.new(7, 2.4, 4.6), fur)
		for _, side in { -1, 1 } do
			-- Trapecios en dos escalones, del hombro al cuello.
			box(nil, "Trap", Vector3.new(side * 3.6, 18.6, -3.4), Vector3.new(3.8, 1.8, 3.8), muscle)
			box(nil, "Trap", Vector3.new(side * 2.4, 19.5, -2.6), Vector3.new(2, 0.8, 2.4), muscle)
			-- Pectorales grandes con su sombra debajo y el surco del esternón entre los dos.
			box(nil, "Pec", Vector3.new(side * 2.8, 11.4, -6.25), Vector3.new(4.6, 3.6, 0.5), furLight)
			box(nil, "PecShadow", Vector3.new(side * 2.8, 9.5, -6.2), Vector3.new(4.4, 0.3, 0.4), shadow)
			-- Abdominales en dos filas en la barriga.
			for _, y in { 8.25, 7.1 } do
				box(nil, "Abs", Vector3.new(side * 1.05, y, -5.8), Vector3.new(1.7, 0.95, 0.4), muscle)
			end
			-- Serrato en el costado del pecho (dos dedos de músculo) y dorsales que abren la espalda en V.
			for _, y in { 11.6, 10.3 } do
				box(nil, "Serratus", Vector3.new(side * 6.45, y, -4.4), Vector3.new(0.3, 0.9, 1.8), muscle)
			end
			box(nil, "Lat", Vector3.new(side * 5.5, 12.4, 1.6), Vector3.new(1, 4.4, 4.4), muscle)
			-- Lumbares a los lados de la columna y glúteos más oscuros, como en los felinos.
			box(nil, "Erector", Vector3.new(side * 1.4, 12.7, 6.6), Vector3.new(1.6, 0.4, 1.6), muscle)
			box(nil, "Glute", Vector3.new(side * 2.4, 9.8, 7.6), Vector3.new(3.8, 4.2, 0.3), fur:Lerp(BLACK, 0.12))
			-- Mechones erizados en los hombros, la grupa y el borde de abajo del pecho.
			box(nil, "Tuft", Vector3.new(side * 4.8, 18.6, -3), Vector3.new(1.4, 1.2, 1.4), furDark)
			box(nil, "Tuft", Vector3.new(side * 3.4, 13, 7), Vector3.new(1.6, 1, 1.2), furDark)
			box(nil, "Tuft", Vector3.new(side * 4.8, 8.6, -4.2), Vector3.new(1.4, 1.2, 1.6), furDark)
		end
		box(nil, "Sternum", Vector3.new(0, 11.4, -6.3), Vector3.new(0.3, 3.4, 0.4), shadow)
		box(nil, "Abs", Vector3.new(0, 7.7, -5.85), Vector3.new(0.3, 2.2, 0.4), shadow)
		-- Cresta de pelo erizado por la columna, entre el casco y la mochila.
		box(nil, "Spine", Vector3.new(0, 19.3, -0.8), Vector3.new(1, 0.8, 1), furDark)
		box(nil, "Spine", Vector3.new(0, 18.6, 0.2), Vector3.new(1, 0.8, 1), furDark)
		-- Fleco de pelo oscuro abajo en la grupa: de espaldas no es un panel liso.
		for _, x in { -3, 0, 3 } do
			box(nil, "Fringe", Vector3.new(x, 7.2, 7.6), Vector3.new(2.4, 1.6, 0.4), furDark)
		end
		scarStrip(nil, Vector3.new(-6.4, 13.4, -2.4), 3)
		scarStrip(nil, Vector3.new(6.1, 12.4, 1.6), 2.6)
		scarStrip(nil, Vector3.new(-4.75, 9.4, 6.2), 2.2)

		-- Casco: bola en escalones (seis cajas), cresta de delante atrás, aro de cobre con el visor de
		-- espejo en cúpula de tres escalones y sus brillos, remaches, discos en las sienes, cuello de
		-- cobre y óxido en dos tonos. Todo mira a los lados con el hueso "Head".
		local helmet: { BasePart } = {}
		local hc = Vector3.new(0, 17.4, -8.5)
		local r = 4.8
		for _, size in
			{
				Vector3.new(2 * r, 1.46 * r, 1.46 * r),
				Vector3.new(1.46 * r, 2 * r, 1.46 * r),
				Vector3.new(1.46 * r, 1.46 * r, 2 * r),
				Vector3.new(1.8 * r, 1.8 * r, 1.1 * r),
				Vector3.new(1.8 * r, 1.1 * r, 1.8 * r),
				Vector3.new(1.1 * r, 1.8 * r, 1.8 * r),
			}
		do
			box(helmet, "Helmet", hc, size, shell)
		end
		local front = hc.Z - r
		box(helmet, "Crest", hc + Vector3.new(0, r + 0.15, 0), Vector3.new(1.2, 0.3, 6.6), crest)
		box(helmet, "Crest", Vector3.new(0, hc.Y, hc.Z + r + 0.15), Vector3.new(1.2, 5.6, 0.3), crest)
		box(helmet, "VisorRim", Vector3.new(0, hc.Y, front - 0.15), Vector3.new(6.6, 6.4, 0.5), copper)
		for _, step in { { 5.4, 5, 0.6, 0.4 }, { 4.2, 3.8, 0.4, 0.8 } } do
			local layer = box(
				helmet,
				"Visor",
				Vector3.new(0, hc.Y, front - step[4]),
				Vector3.new(step[1], step[2], step[3]),
				visorColor
			)
			layer.Reflectance = 0.1
		end
		-- Detrás del cristal se ven brillar los ojos del mono: sin ellos parecía un robot con una
		-- pantalla. Brillos en diagonal arriba a la izquierda y uno pequeño abajo: { x, y, lado }.
		for _, side in { -1, 1 } do
			neon(
				box(
					helmet,
					"VisorEye",
					Vector3.new(side * 1.1, hc.Y + 0.1, front - 1.05),
					Vector3.new(1, 0.7, 0.1),
					color
				),
				0.2
			)
		end
		for _, glint in { { -1.6, 1.3, 0.5 }, { -1, 1.55, 0.35 }, { 1.6, -1.3, 0.35 } } do
			local shine = box(
				helmet,
				"VisorShine",
				Vector3.new(glint[1], hc.Y + glint[2], front - 1.05),
				Vector3.new(glint[3], glint[3], 0.1),
				WHITE
			)
			shine.Transparency = 0.15
		end
		for _, rivet in
			{ { -3, 2.9 }, { 0, 2.9 }, { 3, 2.9 }, { -3, 0 }, { 3, 0 }, { -3, -2.9 }, { 0, -2.9 }, { 3, -2.9 } }
		do
			box(helmet, "Rivet", Vector3.new(rivet[1], hc.Y + rivet[2], front - 0.5), Vector3.new(0.5, 0.5, 0.2), metal)
		end
		for _, side in { -1, 1 } do
			local z = hc.Z + 0.4
			box(helmet, "EarDisc", Vector3.new(side * (r + 0.2), hc.Y, z), Vector3.new(0.4, 3, 3), metal)
			box(helmet, "EarRing", Vector3.new(side * (r + 0.5), hc.Y, z), Vector3.new(0.3, 2.2, 2.2), copper)
			box(helmet, "EarKnob", Vector3.new(side * (r + 0.75), hc.Y, z), Vector3.new(0.4, 1, 1), metal)
		end
		box(helmet, "Collar", hc - Vector3.new(0, r - 0.2, -0.3), Vector3.new(7.6, 1, 7.6), copper)
		-- Óxido: { centro, tamaño } de la mancha grande; la pequeña, más clara, va desplazada encima.
		for _, spot in
			{
				{ Vector3.new(-1.8, 22.3, -7), Vector3.new(2.2, 0.2, 1.6) },
				{ Vector3.new(2, 22.3, -10), Vector3.new(1.4, 0.2, 1.2) },
				{ Vector3.new(4.9, 19.2, -6.6), Vector3.new(0.2, 1.6, 2.2) },
				{ Vector3.new(-4.9, 15.2, -10.4), Vector3.new(0.2, 1.2, 1.8) },
				{ Vector3.new(-2, 18.6, -3.6), Vector3.new(2.2, 1.4, 0.2) },
				{ Vector3.new(1.9, 15.2, -3.6), Vector3.new(1.2, 1, 0.2) },
			}
		do
			local center, size = spot[1], spot[2]
			box(helmet, "Rust", center, size, rust)
			local out = Vector3.new(
				if size.X < 0.5 then math.sign(center.X) * 0.05 else size.X * 0.2,
				if size.Y < 0.5 then 0.05 else -size.Y * 0.15,
				if size.Z < 0.5 then 0.05 else size.Z * 0.2
			)
			box(
				helmet,
				"Rust",
				center + out,
				(size * Vector3.new(0.55, 0.6, 0.55)):Max(Vector3.one * 0.2),
				rust:Lerp(shell, 0.4)
			)
		end
		local helmetJoints: { Joint } = {}
		for _, part in helmet do
			local item = joint(rig, part, CFrame.new(v.at(hc)), Vector3.yAxis, 0.3, 0.7, 0, false)
			item.bone = "Head"
			table.insert(helmetJoints, item)
		end

		-- Antena: base de cobre, varilla con anillos que se estrechan y punta que brilla con su halo.
		-- Cuelga del casco y se balancea por su cuenta.
		local top = hc.Y + r + 0.3
		local antenna: { BasePart } = {}
		box(antenna, "AntennaBase", Vector3.new(0, top + 0.3, hc.Z), Vector3.new(2, 0.6, 2), copper)
		box(antenna, "AntennaRod", Vector3.new(0, top + 2.5, hc.Z), Vector3.new(0.6, 4.2, 0.6), metal)
		for i = 1, 4 do
			local width = 1.9 - i * 0.28
			box(
				antenna,
				"AntennaRing",
				Vector3.new(0, top + 0.5 + i * 0.85, hc.Z),
				Vector3.new(width, 0.45, width),
				if i % 2 == 1 then crest else metal
			)
		end
		local tipAt = Vector3.new(0, top + 5, hc.Z)
		local tip = neon(box(antenna, "AntennaTip", tipAt, Vector3.new(1.4, 1.4, 1.4), color))
		neon(box(antenna, "AntennaGlow", tipAt, Vector3.new(2.2, 2.2, 2.2), color), 0.6)
		for _, part in antenna do
			joint(
				rig,
				part,
				CFrame.new(v.at(Vector3.new(0, top, hc.Z))),
				Vector3.zAxis,
				0.08,
				3,
				0,
				false,
				nil,
				helmetJoints[1]
			)
		end
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 5
		light.Brightness = 1
		light.Parent = tip

		-- Mochila sobre el lomo: caja de metal con su panel, la placa "X-7" a la espalda, rejilla,
		-- pilotos, tornillos, franja de peligro arriba, depósitos con su nivel encendido a los lados,
		-- tirantes por los hombros con hebilla y encima el vial de suero entre dos tapas de cobre.
		local pack = box(nil, "Pack", Vector3.new(0, 15.2, 4.2), Vector3.new(6.6, 5, 3.2), metal)
		box(nil, "PackPanel", Vector3.new(0, 15, 5.85), Vector3.new(5.6, 4.2, 0.1), metal:Lerp(BLACK, 0.25))
		box(nil, "Badge", Vector3.new(0, 15.6, 5.95), Vector3.new(5, 2.3, 0.2), Color3.fromRGB(30, 32, 40))
		-- "X-7" en píxeles de neón sobre la placa (un texto en SurfaceGui dejaba de dibujarse a la
		-- distancia de juego). Se lee desde atrás, con +X a la derecha.
		local glyphs = {
			"X.X.....777",
			"X.X.......7",
			".X..XX...7.",
			"X.X.....7..",
			"X.X.....7..",
		}
		for row, line in glyphs do
			for col = 1, #line do
				if string.sub(line, col, col) ~= "." then
					local at = Vector3.new((col - 0.5) * 0.4 - 2.2, 15.6 + 1 - (row - 0.5) * 0.4, 6.1)
					neon(box(nil, "BadgePixel", at, Vector3.new(0.4, 0.4, 0.1), color))
				end
			end
		end
		neon(
			box(nil, "PackLight", Vector3.new(-2, 13.6, 5.95), Vector3.new(0.6, 0.6, 0.2), Color3.fromRGB(90, 255, 120))
		)
		neon(box(nil, "PackLight", Vector3.new(2, 13.6, 5.95), Vector3.new(0.6, 0.6, 0.2), Color3.fromRGB(255, 70, 60)))
		for _, y in { 13.85, 13.35 } do
			box(nil, "Vent", Vector3.new(0, y, 5.95), Vector3.new(2.4, 0.25, 0.2), Color3.fromRGB(25, 27, 32))
		end
		for _, corner in { { -3, 12.95 }, { 3, 12.95 }, { -3, 17.45 }, { 3, 17.45 } } do
			box(nil, "Bolt", Vector3.new(corner[1], corner[2], 5.9), Vector3.new(0.4, 0.4, 0.2), copper)
		end
		-- Franja de peligro en el borde de arriba, amarilla y negra.
		local stripes = 8
		for i = 1, stripes do
			local stripe = if i % 2 == 1 then Color3.fromRGB(230, 190, 40) else Color3.fromRGB(25, 25, 28)
			box(
				nil,
				"Hazard",
				Vector3.new(-3.15 + (i - 0.5) * 0.7875, 17.55, 5.75),
				Vector3.new(0.79, 0.3, 0.2),
				stripe
			)
		end
		for _, side in { -1, 1 } do
			box(nil, "Tank", Vector3.new(side * 3.8, 15.2, 4.2), Vector3.new(1, 4, 1.6), metal:Lerp(WHITE, 0.15))
			box(nil, "TankCap", Vector3.new(side * 3.8, 17.35, 4.2), Vector3.new(0.7, 0.3, 0.7), copper)
			neon(box(nil, "TankLevel", Vector3.new(side * 4.32, 14.8, 4.2), Vector3.new(0.1, 2.4, 0.4), color), 0.1)
			box(nil, "Strap", Vector3.new(side * 4.2, 19.4, -3.8), Vector3.new(1, 0.2, 6), hose)
			box(nil, "Strap", Vector3.new(side * 4.2, 14.8, -6.65), Vector3.new(1, 9, 0.3), hose)
			box(nil, "StrapBuckle", Vector3.new(side * 4.2, 12.4, -6.85), Vector3.new(1.2, 0.8, 0.2), copper)
		end
		box(nil, "VialCap", Vector3.new(0, 18, 4.2), Vector3.new(2.4, 0.6, 2.4), copper)
		box(nil, "VialCap", Vector3.new(0, 21.2, 4.2), Vector3.new(2.4, 0.6, 2.4), copper)
		local vial = box(nil, "Vial", Vector3.new(0, 19.6, 4.2), Vector3.new(2, 2.6, 2), Color3.fromRGB(200, 240, 255))
		vial.Material = Enum.Material.Glass
		vial.Transparency = 0.5
		local serum = neon(box(nil, "Serum", Vector3.new(0, 19.4, 4.2), Vector3.new(1.3, 2.2, 1.3), color))
		local glow = Instance.new("PointLight")
		glow.Color = color
		glow.Range = 6
		glow.Brightness = 1
		glow.Parent = serum
		-- Chispas en zigzag a los lados del vial.
		for _, side in { -1, 1 } do
			for k = 0, 2 do
				local spark = box(
					nil,
					"Spark",
					Vector3.new(side * (1.9 + (k % 2) * 0.5), 19 + k * 0.8, 4.2),
					Vector3.new(0.3, 0.9, 0.3),
					color:Lerp(WHITE, 0.3)
				)
				neon(spark, 0.15)
			end
		end
		-- Mangueras anilladas de los discos de las sienes a los lados de la mochila: tramos alternos
		-- gruesos de metal y finos de goma sobre una curva.
		local segments = 12
		for _, side in { -1, 1 } do
			local from = Vector3.new(side * 5.4, 15.8, -7.6)
			local control = Vector3.new(side * 7.8, 19.4, -1)
			local to = Vector3.new(side * 3.6, 15.6, 3.4)
			local function at(t: number): Vector3
				return from:Lerp(control, t):Lerp(control:Lerp(to, t), t)
			end
			for i = 1, segments do
				local thick = i % 2 == 1
				local width = if thick then 1.1 else 0.85
				v.beam(
					nil,
					"Hose",
					at((i - 1) / segments),
					at(i / segments),
					Vector2.new(width, width),
					if thick then metal else hose
				)
			end
		end

		for _, side in { -1, 1 } do
			-- Brazo largo y musculoso hasta los nudillos: hombro con sus tres cabezas, bíceps con el
			-- pico, tríceps detrás, la vena de suero que brilla, antebrazo de Popeye con su músculo,
			-- pelo que cuelga detrás, grillete del laboratorio con su luz, mano con tres nudillos y el
			-- pulgar. Cicatriz en el brazo derecho.
			local x = side * 7.9
			local arm: { BasePart } = {}
			box(arm, "Deltoid", Vector3.new(side * 7, 15.2, -3.4), Vector3.new(4.6, 4.2, 4.8), fur)
			box(arm, "DeltoidTop", Vector3.new(side * 7, 17.45, -3.4), Vector3.new(3.4, 0.3, 3.6), muscle)
			box(arm, "FrontDelt", Vector3.new(side * 7.1, 15.4, -6.05), Vector3.new(3.2, 2.8, 0.5), muscle)
			box(arm, "RearDelt", Vector3.new(side * 7.1, 15.2, -0.75), Vector3.new(3.2, 2.6, 0.5), muscle)
			box(arm, "UpperArm", Vector3.new(side * 7.4, 10.6, -5), Vector3.new(3.6, 5.6, 3.8), fur)
			box(arm, "Biceps", Vector3.new(side * 7.4, 11.1, -7.15), Vector3.new(3, 3.4, 0.6), muscle)
			box(
				arm,
				"BicepsPeak",
				Vector3.new(side * 7.4, 11.3, -7.55),
				Vector3.new(1.8, 1.8, 0.3),
				muscle:Lerp(WHITE, 0.06)
			)
			box(arm, "Triceps", Vector3.new(side * 7.4, 11, -2.8), Vector3.new(2.8, 3.6, 0.6), muscle)
			neon(box(arm, "Vein", Vector3.new(side * 9.25, 11.2, -5), Vector3.new(0.15, 2.4, 0.3), color), 0.2)
			neon(box(arm, "Vein", Vector3.new(side * 9.25, 10.1, -5.5), Vector3.new(0.15, 0.3, 1.2), color), 0.2)
			box(arm, "Forearm", Vector3.new(x, 5, -7.2), Vector3.new(4.6, 5.8, 4.6), fur)
			box(arm, "ForearmTop", Vector3.new(x, 6.4, -9.65), Vector3.new(3, 2.2, 0.3), muscle)
			box(arm, "ForearmOuter", Vector3.new(x + side * 2.45, 6.2, -7.2), Vector3.new(0.3, 2.6, 2.8), muscle)
			box(arm, "ArmShag", Vector3.new(side * 8.1, 5.4, -4.7), Vector3.new(2.6, 3.4, 0.8), furDark)
			box(arm, "Cuff", Vector3.new(x, 2.8, -7.3), Vector3.new(5, 1.1, 5), metal)
			neon(box(arm, "CuffLight", Vector3.new(x + side * 2.55, 2.8, -7.3), Vector3.new(0.2, 0.5, 0.9), color))
			box(arm, "Hand", Vector3.new(x, 1, -8), Vector3.new(3.8, 2, 4.4), hands)
			for k = -1, 1 do
				box(arm, "Knuckle", Vector3.new(x + k * 1.25, 0.6, -10.6), Vector3.new(1.1, 1.2, 1), hands)
			end
			box(arm, "Thumb", Vector3.new(side * 5.6, 0.5, -9.3), Vector3.new(0.9, 0.9, 1.6), hands)
			if side == 1 then
				scarStrip(arm, Vector3.new(9.3, 8.6, -5), 2.4)
			end
			for _, part in arm do
				local item = joint(
					rig,
					part,
					CFrame.new(v.at(Vector3.new(side * 6, 14, -3.5))),
					Vector3.xAxis,
					0.35,
					8,
					if side < 0 then 0 else math.pi,
					true
				)
				item.bone = if side < 0 then "ArmL" else "ArmR"
			end

			-- Pata flexionada: muslo hacia delante con el cuádriceps, espinilla con el gemelo por fuera y
			-- el pelo detrás, pie con tres dedos y el gordo hacia dentro. Cicatriz en el muslo izquierdo.
			local leg: { BasePart } = {}
			box(leg, "Thigh", Vector3.new(side * 5.5, 7.6, 3.6), Vector3.new(3.8, 4.2, 5.2), fur)
			box(leg, "ThighTop", Vector3.new(side * 5.6, 9.85, 2.4), Vector3.new(2.6, 0.4, 3), muscle)
			box(leg, "Quad", Vector3.new(side * 5.5, 7.8, 0.85), Vector3.new(3, 3, 0.5), muscle)
			box(leg, "Shin", Vector3.new(side * 5.6, 3.6, 3.2), Vector3.new(3, 4.4, 3), fur)
			box(leg, "Calf", Vector3.new(side * 7.25, 4, 3.2), Vector3.new(0.4, 2.4, 2.2), muscle)
			box(leg, "LegShag", Vector3.new(side * 5.6, 4.4, 4.85), Vector3.new(2.2, 2.6, 0.4), furDark)
			box(leg, "Foot", Vector3.new(side * 5.6, 0.6, 2.6), Vector3.new(3, 1.2, 4.6), hands)
			for k = -1, 1 do
				box(leg, "Toe", Vector3.new(side * 5.6 + k * 1, 0.5, -0.2), Vector3.new(0.9, 1, 0.9), hands)
			end
			box(leg, "BigToe", Vector3.new(side * 3.7, 0.5, 1.4), Vector3.new(0.9, 0.9, 1.4), hands)
			if side == -1 then
				scarStrip(leg, Vector3.new(-7.5, 7.6, 3.6), 3)
			end
			for _, part in leg do
				local item = joint(
					rig,
					part,
					CFrame.new(v.at(Vector3.new(side * 4, 8, 5.5))),
					Vector3.xAxis,
					0.35,
					8,
					if side < 0 then math.pi else 0,
					true
				)
				item.bone = if side < 0 then "LegL" else "LegR"
			end
		end

		-- Aura de energía: chispas azules que salen de la superficie del cuerpo y de la mochila. Desde
		-- dentro y lentas quedaban escondidas; con LightEmission 1 de día salían casi blancas.
		local body = rig.model:FindFirstChild("Body") :: BasePart
		local aura = Instance.new("ParticleEmitter")
		aura.Color = ColorSequence.new(color:Lerp(WHITE, 0.35), color)
		aura.LightEmission = 0.4
		aura.LightInfluence = 0
		aura.Brightness = 2
		aura.Rate = 14
		aura.Lifetime = NumberRange.new(0.6, 1.1)
		aura.Speed = NumberRange.new(1.5, 2.5)
		aura.Drag = 2
		aura.Shape = Enum.ParticleEmitterShape.Sphere
		aura.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		aura.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		aura.Rotation = NumberRange.new(0, 360)
		aura.RotSpeed = NumberRange.new(-180, 180)
		aura.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1 * rig.scale),
			NumberSequenceKeypoint.new(0.2, 0.5 * rig.scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		aura.Transparency = NumberSequence.new(0, 1)
		aura.ZOffset = 1
		aura.Parent = body
		local packAura = aura:Clone()
		packAura.Rate = 8
		packAura.Parent = pack
		rig.family = "X7"
		return "Walk"
	end,
}

-- ===== Clips =====

-- Patas con su seno de andar apagado (mientras el clip las coloca a mano).
local CAT_LEGS_STILL = { FL = 0, FR = 0, BL = 0, BR = 0, FL2 = 0, FR2 = 0, BL2 = 0, BR2 = 0 }

-- Copia "base" y le añade o cambia lo de "extra" (para componer fotogramas a partir de una postura).
local function with(base: Key, extra: Key): Key
	local key = table.clone(base)
	for name, value in extra do
		key[name] = value
	end
	return key
end

-- Clips de cada familia (y de cada mascota, que se suman a los de su familia), hechos a partir de
-- las medidas del rig ("dims"). Los nombres que empiezan por "Idle" son rutinas de reposo:
-- PetFollowers elige una al azar cuando el dueño lleva un rato quieto. "Attack" dura lo que el
-- ataque de PetFollowers y golpea en Config.Pets.StrikeDelaySeconds (0,35 s). "Run" suena con el
-- reloj de las zancadas cuando el dueño corre. "Glide" (aves): alas quietas y abiertas, planeando.
local CLIPS: { [string]: (dims: { [string]: any }) -> { [string]: Clip } } = {}

CLIPS.Cat = function(d)
	-- Sentado: el cuerpo gira sobre la cadera de atrás y baja hasta apoyar las ancas; el ángulo es el
	-- que deja las patas de delante rectas y en el suelo.
	local drop = d.haunch - d.ground
	local reach = (d.hips - d.shoulders).Magnitude
	local s = math.deg(math.asin(math.min(0.9, (drop + 0.04) / reach)))
	drop -= 0.1
	local SIT: Key = {
		Body = { s, 0, 0, 0, -drop, 0 },
		FL = { -s, 0, 0 },
		FR = { -s, 0, 0 },
		BL = { 70 - s, 0, -6 },
		BR = { 70 - s, 0, 6 },
		BL2 = { -120, 0, 0 },
		BR2 = { -120, 0, 0 },
		Head = { -s, 0, 0 },
		Tail = { -5, 18, 0 },
	}
	local lick = { x = 7, speed = 16 }
	local pawToMouth: Key = {
		FR = { 75 - s, 0, -12 },
		FR2 = { 70, 0, 0 },
		Head = { -s - 30, -22, 0 },
		waves = { Head = lick, FR2 = { x = 6, speed = 16, phase = 1 } },
	}
	local faceWash: Key = {
		FR = { 125 - s, 0, -10 },
		FR2 = { 15, 0, 0 },
		Head = { 10 - s, -20, 28 },
		waves = { FR = { x = 14, speed = 7 }, Head = { z = 8, speed = 7 } },
	}
	-- Pata de atrás izquierda arriba: se ladea sobre el anca derecha y estira la pata hacia el
	-- cielo; la cabeza baja hacia el muslo.
	local legUp: Key = {
		Body = { s + 8, 0, -32, 0, 0.2 - drop, 0 },
		FL = { -s - 8, 0, 25 },
		FR = { -s - 8, 0, 30 },
		BL = { 140 - s, 0, -35 },
		BL2 = { 20, 0, 0 },
		BR = { 70 - s, 0, 30 },
		Head = { -75, 105, 0 },
		Tail = { -6, 18, 0 },
		waves = { Head = { x = 8, speed = 15 } },
	}

	-- Tumbado como una esfinge: barriga en el suelo, manos delante y patas de atrás recogidas.
	local lieDrop = d.bodyY - (d.halfHeight or 0.44) - d.ground
	local LIE: Key = {
		Body = { 0, 0, 0, 0, -lieDrop, 0 },
		FL = { 72, 0, 0 },
		FR = { 72, 0, 0 },
		FL2 = { 12, 0, 0 },
		FR2 = { 12, 0, 0 },
		BL = { 80, 0, -8 },
		BR = { 80, 0, 8 },
		BL2 = { -150, 0, 0 },
		BR2 = { -150, 0, 0 },
		Head = { 6, 0, 0 },
		Tail = { 10, 12, 0 },
	}
	local function swish(amplitude: number, speed: number): { [string]: any }
		return { Tail = { y = amplitude, speed = speed, lag = 0.6 } }
	end
	-- De lado y panza arriba (rueda sobre el centro del cuerpo).
	local sideDrop = d.bodyY - d.ground - (d.halfWidth or 0.5)
	local SIDE: Key = {
		Body = { 0, 0, 90, 0, -sideDrop, 0 },
		FL = { 25, 0, 0 },
		FR = { 35, 0, 0 },
		BL = { 20, 0, 0 },
		BR = { 30, 0, 0 },
		Head = { 0, 0, -30 },
		Tail = { 0, 14, 0 },
	}
	local bellyDrop = d.bodyY - d.ground - (d.halfHeight or 0.42) - 0.3
	local BELLY: Key = {
		Body = { 0, 0, 180, 0, -bellyDrop, 0 },
		FL = { 45, 0, 0 },
		FR = { 45, 0, 0 },
		FL2 = { -80, 0, 0 },
		FR2 = { -80, 0, 0 },
		BL = { 30, 0, 0 },
		BR = { 30, 0, 0 },
		BL2 = { -45, 0, 0 },
		BR2 = { -45, 0, 0 },
		Head = { -25, 0, -70 },
		Tail = { 0, 12, 0 },
	}
	local play = {
		FL = { x = 30, speed = 8 },
		FR = { x = 30, speed = 8, phase = math.pi },
		FL2 = { x = 25, speed = 8, phase = 1 },
		FR2 = { x = 25, speed = 8, phase = math.pi + 1 },
		BL = { x = 20, speed = 10 },
		BR = { x = 20, speed = 10, phase = math.pi },
		Body = { z = 10, speed = 2.5 },
		Head = { z = 12, speed = 2.5 },
		Tail = { y = 10, speed = 3 },
	}

	-- Agazapado: patas dobladas, barriga casi en el suelo y cola baja.
	local CROUCH: Key = {
		Body = { -3, 0, 0, 0, -0.4, 0 },
		FL = { -40, 0, 0 },
		FR = { -40, 0, 0 },
		FL2 = { 65, 0, 0 },
		FR2 = { 65, 0, 0 },
		BL = { 45, 0, 0 },
		BR = { 45, 0, 0 },
		BL2 = { -75, 0, 0 },
		BR2 = { -75, 0, 0 },
		Head = { -12, 0, 0 },
		Tail = { 8, 0, 0 },
	}
	local function crouchAt(z: number, extra: Key): Key
		return with(with(CROUCH, { Body = { -3, 0, 0, 0, -0.4, z } }), extra)
	end
	local wiggle = {
		Body = { y = 5, speed = 20 },
		BL = { x = 10, speed = 20 },
		BR = { x = 10, speed = 20, phase = math.pi },
		Tail = { y = 15, speed = 10 },
	}
	local pin: Key = {
		Body = { 8, 0, 0, 0, -0.15, -2.3 },
		FL = { 35, 0, 0 },
		FR = { 35, 0, 0 },
		FL2 = { -20, 0, 0 },
		FR2 = { -20, 0, 0 },
		BL = { 30, 0, 0 },
		BR = { 30, 0, 0 },
		BL2 = { -50, 0, 0 },
		BR2 = { -50, 0, 0 },
		Head = { -30, 0, 0 },
		waves = {
			FL = { x = 20, speed = 12 },
			FR = { x = 20, speed = 12, phase = math.pi },
			Head = { y = 10, speed = 12 },
		},
	}

	-- Arrimado al dueño: se inclina hacia la izquierda (donde está él) con la cabeza y la cola tiesa.
	local RUB: Key = {
		gait = 0.4,
		Body = { 0, 0, 12 },
		Head = { 0, 25, 20 },
		Tail = { -14, 0, 0 },
		waves = {
			Body = { z = 5, speed = 3 },
			Head = { z = 10, speed = 3 },
			Tail = { y = 4, speed = 7 },
		},
	}

	return {
		-- Se sienta, se lame la mano derecha, se lava la cara con ella y luego levanta la pata de
		-- atrás y se la lame.
		IdleGroom = {
			length = 9.6,
			around = d.hips,
			keys = {
				{ t = 0 },
				with(SIT, { t = 0.9 }),
				with(with(SIT, pawToMouth), { t = 1.5 }),
				with(with(SIT, pawToMouth), { t = 3.8 }),
				with(with(SIT, faceWash), { t = 4.3 }),
				with(with(SIT, faceWash), { t = 5.6 }),
				with(SIT, { t = 6.2 }),
				with(with(SIT, legUp), { t = 6.9 }),
				with(with(SIT, legUp), { t = 8.6 }),
				with(SIT, { t = 9 }),
				{ t = 9.6 },
			},
		},
		-- Da una vuelta alrededor de las piernas del dueño (la vuelta la hace PetFollowers)
		-- arrimándole el costado.
		IdleRub = {
			length = 6.5,
			around = d.center,
			keys = {
				{ t = 0, gait = 0.4 },
				with(RUB, { t = 0.6 }),
				with(RUB, { t = 5.9 }),
				{ t = 6.5, gait = 0.4 },
			},
		},
		-- Se tumba, barre el suelo con la cola, apoya la cabeza un rato y se levanta.
		IdleLie = {
			length = 11,
			around = d.center,
			keys = {
				{ t = 0 },
				with(LIE, { t = 1.2, waves = swish(9, 2.2) }),
				with(LIE, { t = 4.2, waves = swish(9, 2.2) }),
				with(LIE, { t = 5, Head = { -16, 0, 6 }, waves = swish(6, 1.6) }),
				with(LIE, { t = 7.6, Head = { -16, 0, 6 }, waves = swish(6, 1.6) }),
				with(LIE, { t = 8.3, waves = swish(11, 2.6) }),
				with(LIE, { t = 10.2, waves = swish(11, 2.6) }),
				{ t = 11 },
			},
		},
		-- Se agazapa, avanza despacio, menea el trasero, salta sobre una presa imaginaria, la
		-- aplasta con las manos y vuelve a su sitio.
		IdleStalk = {
			length = 8.4,
			around = d.center,
			keys = {
				{ t = 0 },
				crouchAt(0, { t = 0.7, gait = 0.25, linear = true }),
				crouchAt(-0.7, { t = 3, gait = 0.25 }),
				crouchAt(-0.7, { t = 3.15, gait = 0, waves = wiggle }),
				crouchAt(-0.7, { t = 3.85, waves = wiggle }),
				crouchAt(-0.7, { t = 4, Body = { -3, 0, 0, 0, -0.48, -0.7 } }),
				{
					t = 4.22,
					Body = { -12, 0, 0, 0, 0.55, -1.7 },
					FL = { 95, 0, 0 },
					FR = { 95, 0, 0 },
					FL2 = { -5, 0, 0 },
					FR2 = { -5, 0, 0 },
					BL = { -50, 0, 0 },
					BR = { -50, 0, 0 },
					BL2 = { 10, 0, 0 },
					BR2 = { 10, 0, 0 },
					Head = { 10, 0, 0 },
					Tail = { -4, 0, 0 },
				},
				with(pin, { t = 4.45 }),
				with(pin, { t = 5.4 }),
				{ t = 5.8, Body = { 0, 0, 0, 0, 0, -2.3 } },
				{ t = 6.3, gait = 0.5, Body = { 0, 180, 0, 0, 0, -2.3 }, linear = true },
				{ t = 7.6, gait = 0.5, Body = { 0, 180, 0, 0, 0, 0 } },
				{ t = 8.1, gait = 0.3, Body = { 0, 0, 0, 0, 0, 0 } },
				{ t = 8.4 },
			},
		},
		-- Se tumba, se pone panza arriba y juega a dar zarpazos al aire y patadas de bicicleta.
		IdleBelly = {
			length = 8.6,
			around = d.center,
			keys = {
				{ t = 0 },
				with(LIE, { t = 0.8 }),
				with(SIDE, { t = 1.4 }),
				with(BELLY, { t = 2, waves = { Tail = play.Tail } }),
				with(BELLY, { t = 2.4, waves = play }),
				with(BELLY, { t = 6.8, waves = play }),
				with(SIDE, { t = 7.3 }),
				with(LIE, { t = 7.9 }),
				{ t = 8.6 },
			},
		},
		-- Galope a saltos: manos juntas y patas juntas, el lomo se balancea y la cola va estirada.
		Run = {
			length = 2 * math.pi / 9,
			loop = true,
			around = d.center,
			keys = {
				{
					t = 0,
					amp = CAT_LEGS_STILL,
					FL2 = { -25, 0, 0 },
					FR2 = { -25, 0, 0 },
					BL2 = { -30, 0, 0 },
					BR2 = { -30, 0, 0 },
					Head = { -6, 0, 0 },
					Tail = { -6, 0, 0 },
					waves = {
						FL = { x = 55, speed = 9 },
						FR = { x = 55, speed = 9, phase = 0.35 },
						BL = { x = 45, speed = 9, phase = math.pi },
						BR = { x = 45, speed = 9, phase = math.pi + 0.35 },
						FL2 = { x = 25, speed = 9, phase = -math.pi / 2 },
						FR2 = { x = 25, speed = 9, phase = 0.35 - math.pi / 2 },
						BL2 = { x = 30, speed = 9, phase = math.pi / 2 },
						BR2 = { x = 30, speed = 9, phase = 0.35 + math.pi / 2 },
						Body = { x = 5, py = 0.12, speed = 9, phase = math.pi / 2 },
						Tail = { x = 4, speed = 9 },
					},
				},
			},
		},
	}
end

-- Patas y orejas de los perros con su seno apagado (mientras el clip las coloca a mano).
local DOG_STILL = with(CAT_LEGS_STILL, { EarL = 0, EarR = 0 })

-- Perros (beagle, labrador y pointer): andar (encima del trote de las patas), galope, sentarse y su
-- pose propia (CLIPS.Beagle, CLIPS.Labrador, CLIPS.Pointer). Orejas: X negativo las echa atrás y Z
-- las abre hacia fuera (negativo en la izquierda, positivo en la derecha).
CLIPS.Dog = function(d)
	-- Sentado: el cuerpo gira sobre la cadera de atrás y baja lo justo para que las manos sigan en el
	-- suelo (rectas) y la esquina de la grupa lo toque. Con la fórmula del felino, los perros, de patas
	-- largas, quedaban casi de pie y con la grupa y las patas de atrás hundidas.
	local reach = (d.hips - d.shoulders).Magnitude
	local height = d.hips.Y - d.ground
	local back, below = d.rump.Z - d.hips.Z, d.hips.Y - d.rump.Y
	local angle = math.asin(math.min(1, height / math.sqrt((reach + back) ^ 2 + below ^ 2)))
		- math.atan2(below, reach + back)
	local drop = reach * math.sin(angle)
	local s = math.deg(angle)
	-- Patas de atrás: el muslo adelante hasta que la rodilla casi roza el suelo y el tramo de abajo
	-- tumbado hacia atrás, un poco inclinado hacia abajo (el pie en el suelo).
	local pivot = height - drop
	local thigh = math.deg(math.acos(math.clamp((pivot - 0.08) / (d.hips.Y - d.knee), -1, 1)))
	-- La cola cae hasta el suelo detrás y barre de lado a lado. Cada tramo suma el giro del anterior
	-- (los giros en X se suman) y el cuerpo inclinado la baja, así que el ángulo se busca: el que deja
	-- la punta justo sobre el suelo (con uno fijo, la del labrador y la del pointer se clavaban).
	local tailShape = d.tail
	local tailBase = tailShape.base - d.hips
	local baseY = d.hips.Y - drop + tailBase.Y * math.cos(angle) - tailBase.Z * math.sin(angle)
	local function tipAbove(bend: number): number
		local y = baseY
		for k, rise in tailShape.rises do
			y += tailShape.segment * math.sin(rise - angle - k * bend)
		end
		return y - d.ground - 0.03
	end
	local low, high = math.rad(-30), math.rad(30)
	for _ = 1, 24 do
		local middle = (low + high) / 2
		if tipAbove(middle) > 0 then
			low = middle
		else
			high = middle
		end
	end
	local sitTail = { math.deg(low), 0, 0 }
	local sweep = { y = 14, speed = 6, lag = 0.5 }
	local SIT: Key = {
		amp = { Tail = 0 },
		Body = { s, 0, 0, 0, -drop, 0 },
		FL = { -s, 0, 0 },
		FR = { -s, 0, 0 },
		BL = { thigh - s, 0, -8 },
		BR = { thigh - s, 0, 8 },
		BL2 = { -85 - thigh, 0, 0 },
		BR2 = { -85 - thigh, 0, 0 },
		Head = { 6 - s, 0, 0 },
		Tail = sitTail,
		waves = { Tail = sweep },
	}
	local function sitWith(extra: Key): Key
		return with(SIT, extra)
	end
	return {
		-- Trote: el cuerpo bota dos veces por zancada, la cabeza cabecea y las orejas rebotan (suena
		-- con el reloj de las zancadas, encima del seno de las patas).
		Walk = {
			length = 2 * math.pi / 9,
			loop = true,
			around = d.center,
			keys = {
				{
					t = 0,
					waves = {
						Body = { x = 1.5, py = 0.035, speed = 18 },
						Head = { x = 3, speed = 18, phase = 0.8 },
						EarL = { x = 9, z = -5, speed = 18, phase = 1.4 },
						EarR = { x = 9, z = 5, speed = 18, phase = 1.4 },
					},
				},
			},
		},
		-- Galope: manos juntas y patas juntas, el lomo se estira y se encoge, la cabeza baja y
		-- adelantada y las orejas hacia atrás, aleteando.
		Run = {
			length = 2 * math.pi / 9,
			loop = true,
			around = d.center,
			keys = {
				{
					t = 0,
					amp = DOG_STILL,
					-- Algo más alto: con las patas recogidas, en el punto bajo del bote se hundía 0,2.
					Body = { 0, 0, 0, 0, 0.06, 0 },
					FL2 = { -25, 0, 0 },
					FR2 = { -25, 0, 0 },
					BL2 = { -30, 0, 0 },
					BR2 = { -30, 0, 0 },
					Head = { -10, 0, 0 },
					Tail = { -4, 0, 0 },
					EarL = { -40, 0, -12 },
					EarR = { -40, 0, 12 },
					waves = {
						FL = { x = 55, speed = 9 },
						FR = { x = 55, speed = 9, phase = 0.35 },
						BL = { x = 50, speed = 9, phase = math.pi },
						BR = { x = 50, speed = 9, phase = math.pi + 0.35 },
						FL2 = { x = 28, speed = 9, phase = -math.pi / 2 },
						FR2 = { x = 28, speed = 9, phase = 0.35 - math.pi / 2 },
						BL2 = { x = 32, speed = 9, phase = math.pi / 2 },
						BR2 = { x = 32, speed = 9, phase = 0.35 + math.pi / 2 },
						Body = { x = 6, py = 0.12, speed = 9, phase = math.pi / 2 },
						Head = { x = 5, speed = 9, phase = math.pi / 2 + 0.5 },
						EarL = { x = 16, speed = 9, phase = 1 },
						EarR = { x = 16, speed = 9, phase = 1 },
						Tail = { x = 5, speed = 9 },
					},
				},
			},
		},
		-- Se sienta, ladea la cabeza (el gesto de perro que escucha), mira a un lado y a otro barriendo
		-- el suelo con la cola y se levanta.
		IdleSit = {
			length = 10,
			around = d.hips,
			keys = {
				{ t = 0 },
				sitWith({ t = 0.9 }),
				sitWith({ t = 2.2 }),
				sitWith({ t = 2.6, Head = { 8 - s, 0, 20 }, EarL = { 0, 0, -12 }, EarR = { 0, 0, 4 } }),
				sitWith({ t = 3.7, Head = { 8 - s, 0, 20 }, EarL = { 0, 0, -12 }, EarR = { 0, 0, 4 } }),
				sitWith({ t = 4.2 }),
				sitWith({ t = 5, Head = { 4 - s, 35, 0 } }),
				sitWith({ t = 6, Head = { 4 - s, 35, 0 } }),
				sitWith({ t = 6.8, Head = { 4 - s, -35, 0 } }),
				sitWith({ t = 7.8, Head = { 4 - s, -35, 0 } }),
				sitWith({ t = 8.5 }),
				sitWith({ t = 9.2 }),
				{ t = 10 },
			},
		},
	}
end

-- Beagle: posición de exposición. Manos rectas, patas de atrás estiradas hacia atrás, el pecho
-- adelante, la cabeza alta y la cola tiesa hacia arriba; se queda quieto, solo respira.
CLIPS.Beagle = function(d)
	local SHOW: Key = {
		amp = with(DOG_STILL, { Tail = 0, Head = 0 }),
		Body = { 2, 0, 0, 0, 0, -0.06 },
		FL = { -2, 0, 0 },
		FR = { -2, 0, 0 },
		-- Con el muslo más atrás, el anca (que va con él) se despegaba del cuerpo como una tabla.
		BL = { -10, 0, -3 },
		BR = { -10, 0, 3 },
		BL2 = { 4, 0, 0 },
		BR2 = { 4, 0, 0 },
		Head = { 8, 0, 0 },
		Tail = { -8, 0, 0 },
		EarL = { 4, 0, 0 },
		EarR = { 4, 0, 0 },
		waves = { Body = { py = 0.015, speed = 3 } },
	}
	return {
		IdleShow = {
			length = 7,
			around = d.center,
			keys = {
				{ t = 0 },
				with(SHOW, { t = 0.8 }),
				with(SHOW, { t = 3.4 }),
				with(SHOW, { t = 3.9, Head = { 8, 18, 0 } }),
				with(SHOW, { t = 5.2, Head = { 8, 18, 0 } }),
				with(SHOW, { t = 5.7 }),
				with(SHOW, { t = 6.3 }),
				{ t = 7 },
			},
		},
	}
end

-- Labrador: se tumba, rueda sobre el costado con las patas estiradas y la cabeza en el suelo, golpea
-- el suelo con la cola, levanta la cabeza para mirar a su dueño y se vuelve a levantar.
CLIPS.Labrador = function(d)
	local lieDrop = d.bodyY - d.halfHeight - d.ground
	local LIE: Key = {
		amp = DOG_STILL,
		Body = { 0, 0, 0, 0, -lieDrop, 0 },
		FL = { 72, 0, 0 },
		FR = { 72, 0, 0 },
		FL2 = { 12, 0, 0 },
		FR2 = { 12, 0, 0 },
		BL = { 80, 0, -8 },
		BR = { 80, 0, 8 },
		BL2 = { -150, 0, 0 },
		BR2 = { -150, 0, 0 },
		Head = { 4, 0, 0 },
	}
	local sideDrop = d.bodyY - d.ground - d.halfWidth
	local SIDE: Key = {
		amp = with(DOG_STILL, { Head = 0 }),
		Body = { 0, 0, 90, 0, -sideDrop, 0 },
		FL = { 30, 0, 0 },
		FR = { 40, 0, 0 },
		FL2 = { -10, 0, 0 },
		FR2 = { -15, 0, 0 },
		BL = { 15, 0, 0 },
		BR = { 25, 0, 0 },
		BL2 = { -15, 0, 0 },
		BR2 = { -20, 0, 0 },
		Head = { -6, 0, -40 },
		-- De lado, el giro en Y de la cola la sube y la baja: golpea el suelo. Cada tramo suma el suyo,
		-- así que poco (con 14 la punta acababa vertical) y con la pose algo levantada para no hundirla.
		Tail = { 0, 5, 0 },
		EarL = { 0, 0, -30 },
		EarR = { 0, 0, 20 },
		waves = { Body = { py = 0.012, speed = 2.4 }, Tail = { y = 5, speed = 7, lag = 0.4 } },
	}
	return {
		IdleSide = {
			length = 12,
			around = d.center,
			keys = {
				{ t = 0 },
				with(LIE, { t = 1 }),
				with(LIE, { t = 1.5 }),
				with(SIDE, { t = 2.3 }),
				with(SIDE, { t = 5.4 }),
				with(SIDE, { t = 6, Head = { -6, 0, -12 } }),
				with(SIDE, { t = 7.2, Head = { -6, 0, -12 } }),
				with(SIDE, { t = 7.8 }),
				with(SIDE, { t = 9.6 }),
				with(LIE, { t = 10.4 }),
				with(LIE, { t = 11 }),
				{ t = 12 },
			},
		},
	}
end

-- Pointer: la muestra. Se congela de golpe con la mano izquierda levantada y doblada, el hocico al
-- frente en línea con el lomo, las orejas atentas y la cola recta hacia atrás; luego se relaja.
CLIPS.Pointer = function(d)
	local POINT: Key = {
		amp = with(DOG_STILL, { Tail = 0, Head = 0 }),
		Body = { -4, 0, 0, 0, -0.04, -0.06 },
		-- Brazo adelante y la mano colgando hacia atrás: más arriba, el hombro (que va con la pata) asomaba.
		FL = { 44, 0, 4 },
		FL2 = { -100, 0, 0 },
		FR = { 4, 0, 0 },
		BL = { 0, 0, 0 },
		BR = { 0, 0, 0 },
		Head = { -4, 0, 0 },
		-- Recta, en línea con el lomo: cada tramo suma su giro y el cuerpo inclinado la levanta, así que
		-- se baja un poco (con -6 subía en diagonal).
		Tail = { 3, 0, 0 },
		EarL = { 10, 0, -6 },
		EarR = { 10, 0, 6 },
	}
	return {
		IdlePoint = {
			length = 7,
			around = d.center,
			keys = {
				{ t = 0 },
				with(POINT, { t = 0.45 }),
				with(POINT, { t = 5.6, waves = { Body = { py = 0.008, speed = 3 } } }),
				with(POINT, { t = 6.1 }),
				{ t = 7 },
			},
		},
	}
end

-- Jaguarundí: se alza sobre las patas de atrás y da dos zarpazos, primero con la derecha.
CLIPS.Jaguarundi = function(d)
	local still = CAT_LEGS_STILL
	return {
		Attack = {
			length = 0.85,
			around = d.hips,
			keys = {
				{ t = 0 },
				{
					t = 0.16,
					amp = still,
					Body = { 48, 0, 0, 0, 0.1, 0 },
					FL = { 20, 0, 0 },
					FR = { 50, 0, 0 },
					BL = { -48, 0, 0 },
					BR = { -48, 0, 0 },
					Head = { -30, 0, 0 },
					Tail = { -6, 0, 0 },
				},
				{
					t = 0.28,
					amp = still,
					Body = { 55, 0, 0, 0, 0.15, 0 },
					FL = { 30, 0, 0 },
					FR = { 120, 0, -10 },
					FR2 = { 50, 0, 0 },
					BL = { -55, 0, 0 },
					BR = { -55, 0, 0 },
					Head = { -32, 0, 0 },
					Tail = { -6, 0, 0 },
				},
				{
					t = 0.37,
					amp = still,
					Body = { 30, 0, 0, 0, 0.05, -0.3 },
					FL = { 40, 0, 0 },
					FR = { 15, 0, 20 },
					FR2 = { -15, 0, 0 },
					BL = { -30, 0, 0 },
					BR = { -30, 0, 0 },
					Head = { -15, -10, 0 },
				},
				{
					t = 0.47,
					amp = still,
					Body = { 42, 0, 0, 0, 0.1, -0.3 },
					FL = { 120, 0, 10 },
					FL2 = { 50, 0, 0 },
					FR = { 40, 0, 0 },
					BL = { -42, 0, 0 },
					BR = { -42, 0, 0 },
					Head = { -25, 0, 0 },
				},
				{
					t = 0.56,
					amp = still,
					Body = { 28, 0, 0, 0, 0.05, -0.35 },
					FL = { 15, 0, -20 },
					FL2 = { -15, 0, 0 },
					FR = { 30, 0, 0 },
					BL = { -28, 0, 0 },
					BR = { -28, 0, 0 },
					Head = { -12, 10, 0 },
				},
				{ t = 0.72, Body = { 0, 0, 0, 0, 0, -0.2 } },
				{ t = 0.85 },
			},
		},
	}
end

-- Ocelote: se agazapa, salta con las manos por delante, cae sobre el mono y lo muerde sacudiendo
-- la cabeza.
CLIPS.Ocelote = function(d)
	local still = CAT_LEGS_STILL
	local bite: Key = {
		amp = still,
		Body = { 14, 0, 0, 0, 0.05, -0.7 },
		FL = { 45, 0, 0 },
		FR = { 45, 0, 0 },
		FL2 = { -35, 0, 0 },
		FR2 = { -35, 0, 0 },
		BL = { 25, 0, 0 },
		BR = { 25, 0, 0 },
		BL2 = { -40, 0, 0 },
		BR2 = { -40, 0, 0 },
		Head = { -40, 0, 0 },
		waves = { Head = { y = 25, z = 8, speed = 34 }, Body = { z = 5, speed = 34 } },
	}
	return {
		Attack = {
			length = 0.85,
			around = d.hips,
			keys = {
				{ t = 0 },
				{
					t = 0.2,
					amp = still,
					Body = { -8, 0, 0, 0, -0.3, 0.15 },
					FL = { -35, 0, 0 },
					FR = { -35, 0, 0 },
					FL2 = { 60, 0, 0 },
					FR2 = { 60, 0, 0 },
					BL = { 45, 0, 0 },
					BR = { 45, 0, 0 },
					BL2 = { -80, 0, 0 },
					BR2 = { -80, 0, 0 },
					Head = { -5, 0, 0 },
					Tail = { -8, 0, 0 },
				},
				{
					t = 0.33,
					amp = still,
					Body = { -14, 0, 0, 0, 0.5, -0.5 },
					FL = { 95, 0, -8 },
					FR = { 95, 0, 8 },
					FL2 = { -10, 0, 0 },
					FR2 = { -10, 0, 0 },
					BL = { -55, 0, 0 },
					BR = { -55, 0, 0 },
					BL2 = { 15, 0, 0 },
					BR2 = { 15, 0, 0 },
					Head = { 18, 0, 0 },
					Tail = { -4, 0, 0 },
				},
				with(bite, { t = 0.42 }),
				with(bite, { t = 0.62 }),
				{ t = 0.85 },
			},
		},
	}
end

-- Mono X-7: salta con los dos puños en alto y los estrella delante (martillazo).
CLIPS.X7 = function()
	local still = { ArmL = 0, ArmR = 0, LegL = 0, LegR = 0 }
	local slam: Key = {
		amp = still,
		Body = { -22, 0, 0, 0, 0, -0.6 },
		ArmL = { 25, 0, 5 },
		ArmR = { 25, 0, -5 },
		LegL = { 25, 0, 0 },
		LegR = { 25, 0, 0 },
		Head = { -10, 0, 0 },
		waves = { Body = { z = 3, speed = 40 } },
	}
	local beat: Key = {
		amp = still,
		Head = { -12, 0, 0 },
		ArmL = { 50, 0, 25 },
		ArmR = { 50, 0, -25 },
		waves = {
			ArmL = { x = 30, speed = 14 },
			ArmR = { x = 30, speed = 14, phase = math.pi },
			Body = { py = 0.03, speed = 14 },
		},
	}
	return {
		Attack = {
			length = 0.85,
			around = Vector3.new(0, -0.2, 0.55),
			keys = {
				{ t = 0 },
				{
					t = 0.14,
					amp = still,
					Body = { -12, 0, 0, 0, -0.15, 0 },
					ArmL = { -35, 0, 0 },
					ArmR = { -35, 0, 0 },
					LegL = { 20, 0, 0 },
					LegR = { 20, 0, 0 },
					Head = { 8, 0, 0 },
				},
				{
					t = 0.27,
					amp = still,
					Body = { 20, 0, 0, 0, 0.6, -0.3 },
					ArmL = { 175, 0, 15 },
					ArmR = { 175, 0, -15 },
					LegL = { -15, 0, 0 },
					LegR = { -15, 0, 0 },
					Head = { 15, 0, 0 },
				},
				with(slam, { t = 0.36 }),
				with(slam, { t = 0.55 }),
				{ t = 0.85 },
			},
		},
		-- Se golpea el pecho con los dos puños, alternándolos, con la cabeza echada atrás.
		IdleChest = {
			length = 5,
			keys = {
				{ t = 0 },
				with(beat, { t = 0.6 }),
				with(beat, { t = 4 }),
				{ t = 5 },
			},
		},
		-- Mira a un lado y a otro con la cabeza.
		IdleLook = {
			length = 5,
			keys = {
				{ t = 0 },
				{ t = 0.8, Head = { 5, 40, 0 } },
				{ t = 2, Head = { 5, 40, 0 } },
				{ t = 2.8, Head = { 5, -40, 0 } },
				{ t = 4, Head = { 5, -40, 0 } },
				{ t = 5 },
			},
		},
	}
end

-- Aves: planean con las alas quietas, un poco levantadas.
CLIPS.Bird = function()
	local look: Key = { Head = { 8, 45, 0 } }
	local other: Key = { Head = { 8, -45, 0 } }
	local flutter: Key = {
		amp = { WingL = 0, WingR = 0 },
		WingL = { 0, 0, -30 },
		WingR = { 0, 0, 30 },
		waves = { WingL = { z = 18, speed = 28 }, WingR = { z = 18, speed = 28, phase = math.pi } },
	}
	return {
		Glide = {
			length = 1,
			loop = true,
			keys = { { t = 0, amp = { WingL = 0, WingR = 0 }, WingL = { 0, 0, -6 }, WingR = { 0, 0, 6 } } },
		},
		-- Mira a un lado y a otro, ladea la cabeza y mueve la cola.
		IdleLook = {
			length = 6,
			keys = {
				{ t = 0 },
				with(look, { t = 0.7 }),
				with(look, { t = 1.8, waves = { Tail = { x = 12, speed = 10 } } }),
				with(other, { t = 2.6 }),
				with(other, { t = 3.8, waves = { Tail = { x = 12, speed = 10 } } }),
				{ t = 4.6, Head = { 20, 0, 18 } },
				{ t = 5.4, Head = { 20, 0, 18 } },
				{ t = 6 },
			},
		},
		-- Sacude las alas un momento, como secándolas.
		IdleFlutter = {
			length = 3,
			keys = { { t = 0 }, with(flutter, { t = 0.3 }), with(flutter, { t = 2.2 }), { t = 3 } },
		},
	}
end

-- Capibara: baja la cabeza y mordisquea la hierba, o se sacude entera. Al correr, trota con la cabeza
-- y el lomo que suben y bajan.
CLIPS.Capibara = function()
	local graze: Key = {
		Head = { 32, 0, 0 },
		Body = { 3, 0, 0 },
		waves = { Head = { x = 7, speed = 16 } },
	}
	local shake: Key = {
		waves = { Body = { z = 5, speed = 28 }, Head = { y = 12, speed = 28 } },
	}
	return {
		IdleGraze = {
			length = 6,
			keys = { { t = 0 }, with(graze, { t = 0.8 }), with(graze, { t = 4.6 }), { t = 6 } },
		},
		IdleShake = {
			length = 3,
			keys = { { t = 0 }, with(shake, { t = 0.3 }), with(shake, { t = 2.3 }), { t = 3 } },
		},
		Run = {
			length = 1,
			loop = true,
			keys = {
				{ t = 0, waves = { Body = { x = 3, py = 0.04, speed = 14 }, Head = { x = 5, speed = 14, phase = 1 } } },
			},
		},
	}
end

-- Ajolote: abre las branquias como un abanico y las agita, mueve la cola de lado a lado mirando a
-- los lados, y al correr serpentea con el cuerpo, la cola y la cabeza.
CLIPS.Ajolote = function()
	local flare: Key = {
		GillL = { 0, 0, -28 },
		GillR = { 0, 0, 28 },
		Head = { -6, 0, 0 },
		waves = { GillL = { z = 7, speed = 16 }, GillR = { z = 7, speed = 16, phase = math.pi } },
	}
	local left: Key = { Head = { 0, 18, 0 }, Tail = { 0, -30, 0 } }
	local right: Key = { Head = { 0, -18, 0 }, Tail = { 0, 30, 0 } }
	return {
		IdleGills = {
			length = 4.5,
			keys = { { t = 0 }, with(flare, { t = 0.5 }), with(flare, { t = 3.6 }), { t = 4.5 } },
		},
		IdleWag = {
			length = 5,
			keys = {
				{ t = 0 },
				with(left, { t = 0.6 }),
				with(right, { t = 1.6 }),
				with(left, { t = 2.6 }),
				with(right, { t = 3.6 }),
				{ t = 5 },
			},
		},
		Run = {
			length = 1,
			loop = true,
			keys = {
				{
					t = 0,
					waves = {
						Body = { y = 5, speed = 12 },
						Tail = { y = 22, speed = 12 },
						Head = { y = 8, speed = 12, phase = 1 },
					},
				},
			},
		},
	}
end

-- Quetzal: al planear, las plumas largas de la cola ondulan y la cabeza se ladea despacio (además del
-- planeo de las aves).
CLIPS.Quetzal = function()
	return {
		Glide = {
			length = 1,
			loop = true,
			keys = {
				{
					t = 0,
					amp = { WingL = 0, WingR = 0 },
					WingL = { 0, 0, -6 },
					WingR = { 0, 0, 6 },
					waves = { Tail = { x = 10, speed = 2.4 }, Head = { z = 6, speed = 1.6 } },
				},
			},
		},
	}
end

-- Colibrí: gira la cabeza a toda prisa y agita la cola (las alas ya baten a su ritmo).
CLIPS.Colibri = function()
	return {
		IdleLook = {
			length = 3.5,
			keys = {
				{ t = 0 },
				{ t = 0.25, Head = { 0, 55, 0 } },
				{ t = 0.9, Head = { 0, 55, 0 }, waves = { Tail = { x = 20, speed = 22 } } },
				{ t = 1.15, Head = { 0, -55, 0 } },
				{ t = 1.9, Head = { 0, -55, 0 }, waves = { Tail = { x = 20, speed = 22 } } },
				{ t = 2.2, Head = { 12, 0, 0 } },
				{ t = 3.5 },
			},
		},
		IdleTilt = {
			length = 3,
			keys = {
				{ t = 0 },
				{ t = 0.4, Head = { 10, 0, 28 } },
				{ t = 1.3, Head = { 10, 0, 28 } },
				{ t = 1.7, Head = { 10, 0, -28 } },
				{ t = 2.5, Head = { 10, 0, -28 } },
				{ t = 3 },
			},
		},
	}
end

-- Rana: infla la garganta y croa, mira a los lados girando el cuerpo y estira una pata de atrás.
CLIPS.Rana = function()
	local croak: Key = {
		Body = { -8, 0, 0, 0, 0.1, 0 },
		FL = { 10, 0, 0 },
		FR = { 10, 0, 0 },
		waves = { Body = { py = 0.04, speed = 16 } },
	}
	return {
		IdleCroak = {
			length = 4.5,
			keys = { { t = 0 }, with(croak, { t = 0.6 }), with(croak, { t = 3.6 }), { t = 4.5 } },
		},
		IdleLook = {
			length = 5,
			keys = {
				{ t = 0 },
				{ t = 0.7, Body = { 0, 35, 0 } },
				{ t = 1.9, Body = { 0, 35, 0 } },
				{ t = 2.8, Body = { 0, -35, 0 } },
				{ t = 4, Body = { 0, -35, 0 } },
				{ t = 5 },
			},
		},
		IdleStretch = {
			length = 4,
			keys = {
				{ t = 0 },
				{ t = 0.7, BL = { -60, 0, 0 }, Body = { 6, 0, 0 } },
				{ t = 2.4, BL = { -60, 0, 0 }, Body = { 6, 0, 0 } },
				{ t = 3.2, FL = { 20, 0, 0 }, FR = { 20, 0, 0 } },
				{ t = 4 },
			},
		},
	}
end

-- Tortuga: saca y gira la cabeza, y estira las aletas hacia fuera.
CLIPS.Tortuga = function()
	return {
		IdleLook = {
			length = 6,
			keys = {
				{ t = 0 },
				{ t = 0.9, Head = { -6, 38, 0 } },
				{ t = 2.4, Head = { -6, 38, 0 } },
				{ t = 3.5, Head = { -6, -38, 0 } },
				{ t = 5, Head = { -6, -38, 0 } },
				{ t = 6 },
			},
		},
		IdleStretch = {
			length = 5,
			keys = {
				{ t = 0 },
				{
					t = 0.9,
					Head = { -18, 0, 0 },
					FL = { 0, -30, 0 },
					FR = { 0, 30, 0 },
					BL = { 0, -20, 0 },
					BR = { 0, 20, 0 },
				},
				{
					t = 3.4,
					Head = { -18, 0, 0 },
					FL = { 0, -30, 0 },
					FR = { 0, 30, 0 },
					BL = { 0, -20, 0 },
					BR = { 0, 20, 0 },
					waves = { FL = { y = 8, speed = 6 }, FR = { y = 8, speed = 6, phase = math.pi } },
				},
				{ t = 5 },
			},
		},
	}
end

-- Perezoso: bosteza muy despacio, se rasca con un brazo y mira a los lados; al correr, se bambolea.
CLIPS.Perezoso = function()
	return {
		IdleYawn = {
			length = 6,
			keys = {
				{ t = 0 },
				{ t = 1.6, Head = { -22, 0, 0 } },
				{ t = 3.6, Head = { -22, 0, 0 }, waves = { Head = { x = 3, speed = 3 } } },
				{ t = 6 },
			},
		},
		IdleScratch = {
			length = 6,
			keys = {
				{ t = 0 },
				{ t = 1.2, FL = { -110, 0, 15 }, Head = { 8, 0, 14 } },
				{ t = 1.4, FL = { -110, 0, 15 }, Head = { 8, 0, 14 }, waves = { FL = { x = 14, speed = 9 } } },
				{ t = 4.6, FL = { -110, 0, 15 }, Head = { 8, 0, 14 }, waves = { FL = { x = 14, speed = 9 } } },
				{ t = 6 },
			},
		},
		IdleLook = {
			length = 7,
			keys = {
				{ t = 0 },
				{ t = 1.6, Head = { 0, 32, 0 } },
				{ t = 3, Head = { 0, 32, 0 } },
				{ t = 4.6, Head = { 0, -32, 0 } },
				{ t = 5.6, Head = { 0, -32, 0 } },
				{ t = 7 },
			},
		},
		Run = {
			length = 1,
			loop = true,
			keys = { { t = 0, waves = { Body = { z = 4, speed = 7 }, Head = { z = 8, speed = 7, phase = 1 } } } },
		},
	}
end

-- Skins de mascota (Data/Cosmetics, tipo PetSkin), por id del cosmético:
--   palette    colores que cambian (las claves que el constructor lee con "tone")
--   materials  material de las piezas que llevan ese color de la paleta (Neon para la lava)
--   extra      piezas propias, con la misma rejilla que el constructor (voxelKit)
-- Cuanto más rara la skin, más detalle (Data/Cosmetics): una Rara cambia los colores y los materiales
-- y lleva un motivo propio.
type Skin = {
	palette: { [string]: Color3 },
	materials: { [string]: Enum.Material }?,
	extra: ((rig: Rig) -> ())?,
}

-- El neón aclara mucho: para que la lava se lea naranja (y no amarilla) va muy saturada.
local LAVA = Color3.fromRGB(255, 85, 10)
local LAVA_HOT = Color3.fromRGB(255, 140, 30)
local BASALT = Color3.fromRGB(52, 44, 42)
local OBSIDIAN = Color3.fromRGB(34, 27, 30)

local SKINS: { [string]: Skin } = {
	-- Tortuga de Lava: caparazón de basalto en capas con el borde de obsidiana, placas de lava que
	-- brillan arriba (las grietas), piel de carbón con escamas rojizas (de neón parecían manchas de
	-- leopardo) y ojos de fuego; encima, un volcancito con su cráter de lava, coladas por los lados,
	-- humo y brasas.
	LavaTurtleSkin = {
		palette = {
			skin = Color3.fromRGB(72, 56, 48),
			scale = Color3.fromRGB(150, 55, 30),
			olive = BASALT,
			crown = Color3.fromRGB(40, 34, 36),
			yellow = LAVA,
			brown = Color3.fromRGB(95, 38, 26),
			rim = OBSIDIAN,
			plastron = Color3.fromRGB(85, 70, 60),
			eye = LAVA_HOT,
		},
		materials = {
			olive = Enum.Material.Basalt,
			crown = Enum.Material.Basalt,
			yellow = Enum.Material.Neon,
			eye = Enum.Material.Neon,
		},
		extra = function(rig)
			local v = voxelKit(rig, Vector3.new(0, 4, 0))
			local box = v.box
			local cone = Color3.fromRGB(44, 36, 36)
			-- Cono en tres escalones sobre la cima del caparazón y el cráter, un aro con la lava casi
			-- rebosando (se ve desde la altura de la cámara).
			for _, step in { { 8.3, 6, 6.6 }, { 9.3, 4.6, 5 }, { 10.3, 3.2, 3.6 } } do
				box(nil, "Volcano", Vector3.new(0, step[1], 0.5), Vector3.new(step[2], 1, step[3]), cone).Material =
					Enum.Material.Basalt
			end
			for _, wall in
				{
					{ 0, -0.75, 2.6, 0.5 },
					{ 0, 1.75, 2.6, 0.5 },
					{ -1.05, 0.5, 0.5, 2 },
					{ 1.05, 0.5, 0.5, 2 },
				}
			do
				box(nil, "Crater", Vector3.new(wall[1], 11.1, wall[2]), Vector3.new(wall[3], 0.6, wall[4]), OBSIDIAN)
			end
			local pool = box(nil, "CraterLava", Vector3.new(0, 11.1, 0.5), Vector3.new(1.6, 0.5, 2), LAVA_HOT)
			pool.Material = Enum.Material.Neon
			-- Coladas que bajan del cráter por los escalones del cono: delante, a cada lado y detrás.
			for _, drip in
				{
					{ Vector3.new(0.6, 10.3, -1.35), Vector3.new(0.5, 1, 0.2) },
					{ Vector3.new(0.6, 9.4, -2.05), Vector3.new(0.5, 1.2, 0.2) },
					{ Vector3.new(0.9, 8.4, -2.85), Vector3.new(0.5, 1, 0.2) },
					{ Vector3.new(-1.65, 10.3, 1), Vector3.new(0.2, 1, 0.5) },
					{ Vector3.new(-2.35, 9.4, 1.3), Vector3.new(0.2, 1.2, 0.5) },
					{ Vector3.new(-3.05, 8.4, 1.5), Vector3.new(0.2, 1, 0.5) },
					{ Vector3.new(1.65, 10.4, 1.6), Vector3.new(0.2, 0.8, 0.5) },
					{ Vector3.new(2.35, 9.5, 1.9), Vector3.new(0.2, 1, 0.5) },
					{ Vector3.new(-0.4, 10.3, 2.35), Vector3.new(0.5, 1, 0.2) },
					{ Vector3.new(-0.4, 9.4, 3.05), Vector3.new(0.5, 1.2, 0.2) },
					{ Vector3.new(-0.6, 8.4, 3.85), Vector3.new(0.5, 1, 0.2) },
				}
			do
				box(nil, "LavaDrip", drip[1], drip[2], LAVA).Material = Enum.Material.Neon
			end
			-- Humo gris que sube despacio y brasas que saltan del cráter.
			local vent = Instance.new("Attachment")
			vent.Name = "Vent"
			vent.Position = Vector3.new(0, 0.3 * CELL * rig.scale, 0)
			vent.Parent = pool
			local smoke = Instance.new("ParticleEmitter")
			smoke.Name = "Smoke"
			smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
			smoke.Color = ColorSequence.new(Color3.fromRGB(110, 100, 100), Color3.fromRGB(70, 65, 65))
			smoke.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25 * rig.scale),
				NumberSequenceKeypoint.new(1, 0.9 * rig.scale),
			})
			smoke.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			})
			smoke.Rate = 4
			smoke.Lifetime = NumberRange.new(1.4, 2.2)
			smoke.Speed = NumberRange.new(0.8, 1.4)
			smoke.SpreadAngle = Vector2.new(12, 12)
			smoke.RotSpeed = NumberRange.new(-30, 30)
			smoke.Parent = vent
			local embers = Instance.new("ParticleEmitter")
			embers.Name = "Embers"
			embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			embers.Color = ColorSequence.new(LAVA_HOT, LAVA)
			embers.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.18 * rig.scale),
				NumberSequenceKeypoint.new(1, 0),
			})
			embers.LightEmission = 0.4
			embers.Brightness = 2
			embers.LightInfluence = 0
			embers.Rate = 5
			embers.Lifetime = NumberRange.new(0.5, 0.9)
			embers.Speed = NumberRange.new(1.5, 2.5)
			embers.SpreadAngle = Vector2.new(30, 30)
			embers.Acceleration = Vector3.new(0, -4, 0)
			embers.ZOffset = 1
			embers.Parent = vent
		end,
	},
	-- Jaguar de Magma (pase, legendario, skin de familia de los tres felinos): pelaje de basalto con
	-- rosetas, rayas y anillos de lava (el jaguarundí, que no tiene manchas, las lleva con la skin),
	-- vientre de brasa apagada, patas de obsidiana con los dedos de lava y ojos de fuego. Encima, una
	-- grieta de lava en zigzag a lo largo del lomo entre rocas de obsidiana, que humea y suelta brasas,
	-- y la cola acaba en una llama de bloques (se ve también en la imagen del pase) con su fuego. En el
	-- de cristal, los cristales son de obsidiana con el corazón de lava, y no lleva rocas.
	MagmaJaguarSkin = {
		palette = {
			coat = Color3.fromRGB(58, 48, 50),
			spots = LAVA,
			belly = Color3.fromRGB(105, 45, 30),
			muzzle = Color3.fromRGB(80, 66, 66),
			paw = OBSIDIAN,
			toe = LAVA_HOT,
			eye = Color3.fromRGB(255, 200, 50),
			crystal = OBSIDIAN,
			crystalGlow = LAVA,
		},
		materials = {
			spots = Enum.Material.Neon,
			toe = Enum.Material.Neon,
			eye = Enum.Material.Neon,
		},
		extra = function(rig)
			local dims = rig.dims
			if not dims then
				return
			end
			local length: number = dims.length
			local top: number = dims.halfHeight
			local waist = 0.4 * VOXEL
			local bend = rig.bend
			-- Bloque en studs (sin escalar) con medidas en celdas; los de detrás de la cintura se doblan
			-- con la cadera.
			local function block(name: string, center: Vector3, size: Vector3, color: Color3): BasePart
				local part = piece(rig, name, "Block", size * VOXEL, CFrame.new(center), color, Enum.Material.Neon)
				if bend and center.Z > waist then
					table.insert(bend.parts, part)
				end
				return part
			end
			-- Grieta: tramos de 2 celdas que se tuercen a un lado y a otro, de la nuca a la cola.
			local from, to = -length / 2 + VOXEL, length / 2 - 1.2 * VOXEL
			local count = math.floor((to - from) / (2 * VOXEL))
			local vent: BasePart? = nil
			for index = 1, count do
				local z = from + (index - 0.5) * (to - from) / count
				local part = block(
					"LavaCrack",
					Vector3.new((if index % 2 == 0 then 0.35 else -0.35) * VOXEL, top + 0.1 * VOXEL, z),
					Vector3.new(0.8, 0.3, 2.4),
					if index % 3 == 0 then LAVA_HOT else LAVA
				)
				if index == math.ceil(count / 3) then
					vent = part
				end
			end
			-- Rocas de obsidiana a los dos lados de la grieta, más altas en los hombros.
			if not rig.model:FindFirstChild("Crystal") then
				for index, z in { -6, -3, 0, 3, 6 } do
					for _, side in { -1, 1 } do
						local tall = 1.6 - index * 0.2
						block(
							"Obsidian",
							Vector3.new(side * 1.4 * VOXEL, top + tall / 2 * VOXEL, (z + side * 0.4) * VOXEL),
							Vector3.new(1.2, tall, 1.8),
							OBSIDIAN
						).Material =
							Enum.Material.Basalt
					end
				end
			end
			if vent then
				local smoke = Instance.new("ParticleEmitter")
				smoke.Name = "Smoke"
				smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
				smoke.Color = ColorSequence.new(Color3.fromRGB(95, 85, 85), Color3.fromRGB(60, 55, 55))
				smoke.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.2 * rig.scale),
					NumberSequenceKeypoint.new(1, 0.8 * rig.scale),
				})
				smoke.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.55),
					NumberSequenceKeypoint.new(1, 1),
				})
				smoke.Rate = 3
				smoke.Lifetime = NumberRange.new(1.2, 1.8)
				smoke.Speed = NumberRange.new(0.6, 1.1)
				smoke.SpreadAngle = Vector2.new(15, 15)
				smoke.RotSpeed = NumberRange.new(-30, 30)
				smoke.Parent = vent
				local embers = Instance.new("ParticleEmitter")
				embers.Name = "Embers"
				embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				embers.Color = ColorSequence.new(LAVA_HOT, LAVA)
				embers.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.15 * rig.scale),
					NumberSequenceKeypoint.new(1, 0),
				})
				embers.LightEmission = 0.4
				embers.Brightness = 2
				embers.LightInfluence = 0
				embers.Rate = 5
				embers.Lifetime = NumberRange.new(0.6, 1)
				embers.Speed = NumberRange.new(1.2, 2.2)
				embers.SpreadAngle = Vector2.new(25, 25)
				embers.Acceleration = Vector3.new(0, -3, 0)
				embers.ZOffset = 1
				embers.Parent = vent
			end
			local body = rig.model:FindFirstChild("Body")
			if body then
				local light = Instance.new("PointLight")
				light.Name = "MagmaGlow"
				light.Color = LAVA
				light.Range = 7
				light.Brightness = 0.9
				light.Parent = body
			end
			-- La llama de la punta de la cola: bloques que suben y se aclaran, y su fuego.
			local tip = rig.model:FindFirstChild("TailTip")
			if tip and tip:IsA("BasePart") then
				local tipEnd = (tip.CFrame * CFrame.new(0, 0, -tip.Size.Z / 2)).Position / rig.scale
				local flame: BasePart? = nil
				for _, step in
					{
						{ 0.6, 2.4, LAVA },
						{ 2, 1.9, LAVA },
						{ 3.3, 1.4, LAVA_HOT },
						{ 4.5, 0.9, Color3.fromRGB(255, 215, 80) },
						{ 5.5, 0.5, Color3.fromRGB(255, 240, 160) },
					}
				do
					local height: number, width: number, color: Color3 = step[1], step[2], step[3]
					flame = piece(
						rig,
						"TailFlame",
						"Block",
						Vector3.new(width, 1.3, width) * VOXEL,
						CFrame.new(tipEnd + Vector3.new(0, height, height * 0.15) * VOXEL),
						color,
						Enum.Material.Neon
					)
					attachTo(rig, flame :: BasePart, tip)
				end
				if flame then
					local fire = Instance.new("ParticleEmitter")
					fire.Name = "Fire"
					fire.Texture = "rbxasset://textures/particles/fire_main.dds"
					fire.Color = ColorSequence.new(LAVA_HOT, LAVA)
					fire.Size = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.3 * rig.scale),
						NumberSequenceKeypoint.new(1, 0),
					})
					fire.LightEmission = 0.8
					fire.Rate = 14
					fire.Lifetime = NumberRange.new(0.3, 0.5)
					fire.Speed = NumberRange.new(0.6, 1.2)
					fire.SpreadAngle = Vector2.new(10, 10)
					fire.Parent = flame
				end
			end
		end,
	},
	-- Perro pirata (tienda, skin de familia de los tres perros): cada uno con su pelaje, para que se
	-- reconozca, y el equipo que dibuja voxelDog con estos colores: pañuelo rojo con lunares, parche,
	-- aro de oro, camiseta de marinero blanca y azul marino y la bandera pirata en su mástil.
	PirateDogSkin = {
		palette = {
			bandana = Color3.fromRGB(205, 35, 35),
			eyePatch = Color3.fromRGB(25, 22, 25),
			earring = Color3.fromRGB(240, 195, 60),
			shirt = Color3.fromRGB(240, 240, 232),
			shirtStripe = Color3.fromRGB(35, 55, 125),
			flag = Color3.fromRGB(28, 24, 30),
		},
		materials = { earring = Enum.Material.Metal },
	},
}

-- Fase 21: mallas con textura. Las piezas de una mascota se agrupan por lo que las mueve: todas las de la misma
-- articulación (misma bisagra, eje, seno, hueso…) son un grupo, y las fijas son el grupo "Static". Cada grupo puede
-- ser una `MeshPart` (Data/PetMeshes) que se mueve con la misma articulación.
type MeshBox = { part: BasePart, center: Vector3, size: Vector3 }
type MeshGroup = {
	name: string,
	hinge: Vector3, -- origen del grupo, sin escalar (la bisagra, o el pivote en "Static")
	joints: { Joint }, -- las articulaciones de sus piezas (vacío en "Static")
	boxes: { MeshBox }, -- las piezas que puede llevar la malla
	loose: number, -- las que no (giradas, de otro material, con forma redonda)
	bend: boolean?, -- la cadera que se dobla al girar (rig.bend): su malla va en la lista de piezas de la cadera
}

-- Centro y tamaño (sin escalar, respecto a "origin" en ejes del pivote) de una pieza que puede ir a la malla, o nil si
-- tiene que seguir suelta: no es un bloque, tiene otro material o brillo, o está girada.
local function meshableBox(part: BasePart, origin: Vector3, scale: number): (Vector3?, Vector3?)
	if
		not part:IsA("Part")
		or (part :: Part).Shape ~= Enum.PartType.Block
		or part:FindFirstChildWhichIsA("SpecialMesh")
	then
		return nil, nil
	end
	if part.Material ~= Enum.Material.SmoothPlastic or part.Transparency > 0 or part.Reflectance > 0 then
		return nil, nil
	end
	local _, _, _, r11, r12, r13, r21, r22, r23, r31, r32, r33 = part.CFrame:GetComponents()
	local rows = { { r11, r12, r13 }, { r21, r22, r23 }, { r31, r32, r33 } }
	local own = { part.Size.X, part.Size.Y, part.Size.Z }
	local size = { 0, 0, 0 }
	for i, row in rows do
		for j, value in row do
			local abs = math.abs(value)
			if abs > 0.999 then
				size[i] = own[j]
			elseif abs > 0.001 then
				return nil, nil
			end
		end
		if size[i] == 0 then
			return nil, nil
		end
	end
	return (part.Position - origin * scale) / scale, Vector3.new(size[1], size[2], size[3]) / scale
end

local function meshGroups(model: Model): { MeshGroup }
	local animated = rigs[model]
	local groups: { MeshGroup } = {}
	if not animated then
		return groups
	end
	local scale = animated.scale
	local byKey: { [string]: MeshGroup } = {}
	local keys: { [Joint]: string } = {}
	local used: { [string]: number } = {}
	local function add(key: string, bone: string?, hinge: Vector3): MeshGroup
		local group = byKey[key]
		if not group then
			local base = bone or "J"
			used[base] = (used[base] or 0) + 1
			local name = if used[base] == 1 and bone then base else base .. used[base]
			group = { name = name, hinge = hinge, joints = {}, boxes = {}, loose = 0 }
			byKey[key] = group
			table.insert(groups, group)
		end
		return group
	end
	local static = add("Static", "Static", Vector3.zero)
	local function place(group: MeshGroup, part: BasePart)
		local center, size = meshableBox(part, group.hinge, scale)
		if center and size then
			table.insert(group.boxes, { part = part, center = center, size = size })
		else
			group.loose += 1
		end
	end
	for _, item in animated.joints do
		local hinge = item.hinge.Position / scale
		local parentKey = if item.parent then keys[item.parent] or "?" else ""
		local key = string.format(
			"%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%.4f|%.4f|%.4f|%s|%.4f|%s|%.3f|%.3f|%s",
			hinge.X,
			hinge.Y,
			hinge.Z,
			item.axis.X,
			item.axis.Y,
			item.axis.Z,
			item.amplitude,
			item.speed,
			item.phase,
			tostring(item.gait),
			item.bias,
			item.bone or "",
			item.lag,
			item.bend,
			parentKey
		)
		keys[item] = key
		local group = add(key, item.bone, hinge)
		table.insert(group.joints, item)
		place(group, item.part)
	end
	for _, part in animated.statics do
		place(static, part)
	end
	local bendRig = animated.bend
	if bendRig then
		local hip = add("Hip", "Hip", bendRig.hinge.Position / scale)
		hip.bend = true
		for _, part in bendRig.parts do
			place(hip, part)
		end
	end
	return groups
end

-- Los grupos de una mascota con sus bloques para la malla (lo usa el volcado de ServerStorage.Tools.Mallas).
function PetModels.meshGroups(model: Model): { MeshGroup }
	return meshGroups(model)
end

local meshCache: { [string]: MeshPart } = {}
local meshLoading: { [string]: boolean } = {}
local meshReadyCallbacks: { (petId: string) -> () } = {}
local meshAnnounced: { [string]: boolean } = {}

-- Si ya están cargadas todas las mallas de la mascota.
local function meshesReady(petId: string): boolean
	local meshes = PetMeshes[petId]
	if not meshes then
		return false
	end
	for _, entry in meshes.parts do
		if entry.mesh == "" or entry.texture == "" or not meshCache[entry.mesh] then
			return false
		end
	end
	return true
end

-- Avisa (una vez por mascota) cuando sus mallas acaban de cargar: quien ya construyó la mascota con bloques (el
-- cliente la construye al entrar, antes de que lleguen las mallas) la reconstruye entonces.
function PetModels.onMeshesReady(callback: (petId: string) -> ())
	table.insert(meshReadyCallbacks, callback)
end

-- Pide a Roblox las mallas de una mascota, cada una en su hilo; `build` las usa cuando ya están todas.
function PetModels.preload(petId: string)
	local meshes = PetMeshes[petId]
	if not meshes then
		return
	end
	for _, entry in meshes.parts do
		if entry.mesh ~= "" and entry.texture ~= "" and not meshCache[entry.mesh] and not meshLoading[entry.mesh] then
			meshLoading[entry.mesh] = true
			task.spawn(function()
				local ok, mesh = pcall(function()
					return AssetService:CreateMeshPartAsync(Content.fromUri(entry.mesh))
				end)
				if ok then
					meshCache[entry.mesh] = mesh
				else
					warn(`[PetModels] No se pudo cargar la malla de {petId}: {mesh}`)
				end
				meshLoading[entry.mesh] = nil
				if meshesReady(petId) and not meshAnnounced[petId] then
					meshAnnounced[petId] = true
					for _, callback in meshReadyCallbacks do
						task.spawn(callback, petId)
					end
				end
			end)
		end
	end
end

-- Pide las mallas de todas las mascotas que las tienen (al arrancar el cliente, para que no salga la versión de bloques).
function PetModels.preloadAll()
	for petId in PetMeshes do
		PetModels.preload(petId)
	end
end

-- Sustituye los bloques de cada grupo con malla por su `MeshPart`, con la misma articulación que movía a los bloques.
local function applyMeshes(model: Model, animated: Animated, meshes: PetMeshes.PetMesh, factor: number)
	local replaced: { [Joint]: Joint } = {}
	local removedParts: { [BasePart]: boolean } = {}
	for _, group in meshGroups(model) do
		local entry = meshes.parts[group.name]
		local cached = if entry then meshCache[entry.mesh] else nil
		if not (entry and cached and #group.boxes > 0) then
			continue
		end
		local mesh = cached:Clone()
		mesh.Size *= factor / meshes.scale
		mesh.TextureID = entry.texture
		mesh.Color = Color3.new(1, 1, 1)
		mesh.Material = Enum.Material.SmoothPlastic
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanQuery = false
		mesh.CanTouch = false
		mesh.CastShadow = false
		mesh.Name = `{group.name}Mesh`
		mesh.CFrame = CFrame.new(group.hinge * animated.scale)
			* CFrame.new(entry.offset * factor / meshes.scale)
			* CFrame.Angles(0, math.pi, 0)
			* mesh.ExtentsCFrame:Inverse()
		mesh.Parent = model
		local source = group.joints[1]
		if source then
			-- La malla lleva la articulación de su grupo; los bloques del grupo pierden la suya.
			local copy = table.clone(source)
			copy.part = mesh
			copy.offset = source.hinge:Inverse() * mesh.CFrame
			table.insert(animated.joints, copy)
			for _, item in group.joints do
				replaced[item] = copy
			end
		elseif group.bend and animated.bend then
			table.insert(animated.bend.parts, mesh)
			table.insert(animated.bend.rest, mesh.CFrame)
		else
			table.insert(animated.statics, mesh)
			table.insert(animated.rest, mesh.CFrame)
		end
		for _, box in group.boxes do
			removedParts[box.part] = true
		end
	end
	if next(removedParts) == nil then
		return
	end
	local kept: { Joint } = {}
	for _, item in animated.joints do
		if not removedParts[item.part] then
			if item.parent and replaced[item.parent] then
				item.parent = replaced[item.parent]
			end
			table.insert(kept, item)
		end
	end
	table.clear(animated.joints)
	table.move(kept, 1, #kept, 1, animated.joints)
	local statics, rest = {}, {}
	for i, part in animated.statics do
		if not removedParts[part] then
			table.insert(statics, part)
			table.insert(rest, animated.rest[i])
		end
	end
	animated.statics, animated.rest = statics, rest
	local bendRig = animated.bend
	if bendRig then
		local bendParts, bendRest = {}, {}
		for i, part in bendRig.parts do
			if not removedParts[part] then
				table.insert(bendParts, part)
				table.insert(bendRest, bendRig.rest[i])
			end
		end
		bendRig.parts, bendRig.rest = bendParts, bendRest
	end
	for part in removedParts do
		part:Destroy()
	end
end

-- Si "skinId" es una skin dibujada que le vale a "petId" (la suya o la de su familia).
function PetModels.hasSkin(skinId: string, petId: string): boolean
	local cosmetic = Cosmetics[skinId]
	return SKINS[skinId] ~= nil and cosmetic ~= nil and CosmeticSlots.fitsPet(cosmetic, petId)
end

-- Construye la mascota "petId", con la skin "skinId" si le vale.
function PetModels.build(petId: string, skinId: string?, boxesOnly: boolean?): Model?
	local pet = Pets[petId]
	local builder = voxelBuilders[petId] or builders[petId]
	if not (pet and builder) then
		return nil
	end
	local skin = if skinId and PetModels.hasSkin(skinId, petId) then SKINS[skinId] else nil
	local model = Instance.new("Model")
	model.Name = `Mascota_{petId}`
	local rig: Rig = { model = model, scale = pet.size, joints = {}, palette = if skin then skin.palette else nil }
	local root = piece(rig, "Root", "Block", Vector3.one * 0.2, CFrame.identity, WHITE)
	root.Transparency = 1
	model.PrimaryPart = root
	local motion = builder(rig, pet.color)
	if skin then
		-- El material va por color: cada clave de la paleta con el suyo (comparado en hex, que es como
		-- guarda la pieza el color).
		local materials: { [string]: Enum.Material } = {}
		for key, material in skin.materials or {} do
			local color = skin.palette[key]
			if color then
				materials[color:ToHex()] = material
			end
		end
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part ~= root then
				local material = materials[part.Color:ToHex()]
				if material then
					part.Material = material
				end
			end
		end
		if skin.extra then
			skin.extra(rig)
		end
		model:SetAttribute("Skin", skinId)
	end
	local box, size = model:GetBoundingBox()
	model:SetAttribute("Motion", motion)
	model:SetAttribute("Height", -(box.Position.Y - size.Y / 2))
	-- Clips de su familia y los suyos propios.
	local clips: { [string]: Clip } = {}
	local dims = rig.dims or {}
	for _, source in { if rig.family then CLIPS[rig.family] else nil, CLIPS[petId] } do
		for name, clip in source(dims) do
			clips[name] = clip
		end
	end
	-- Piezas fijas: solo se mueven cuando un clip mueve el cuerpo entero.
	local moving: { [BasePart]: boolean } = {}
	for _, item in rig.joints do
		moving[item.part] = true
	end
	-- Piezas de la cadera que se doblan al girar: aparte de las fijas.
	local bend = nil
	if rig.bend then
		local bendRest = {}
		for i, part in rig.bend.parts do
			moving[part] = true
			bendRest[i] = part.CFrame
		end
		bend = {
			hinge = scaled(rig, rig.bend.hinge),
			factor = rig.bend.factor,
			parts = rig.bend.parts,
			rest = bendRest,
		}
	end
	local statics: { BasePart } = {}
	local rest: { CFrame } = {}
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= root and not moving[part] then
			table.insert(statics, part)
			table.insert(rest, part.CFrame)
		end
	end
	rigs[model] = {
		joints = rig.joints,
		statics = statics,
		rest = rest,
		clips = clips,
		scale = rig.scale,
		bodyMoved = false,
		bend = bend,
		bendMoved = false,
	}
	model.Destroying:Connect(function()
		rigs[model] = nil
	end)
	-- Mallas (Fase 21): solo la mascota sin skin, y solo cuando ya han cargado todas; si no, se queda con bloques y las pide.
	local meshes = PetMeshes[petId]
	if meshes and not skin and not boxesOnly then
		if meshesReady(petId) then
			applyMeshes(model, rigs[model], meshes, pet.size)
			model:SetAttribute("Meshed", true)
		else
			PetModels.preload(petId)
		end
	end
	return model
end

-- Clips que tiene una mascota y lo que dura cada uno.
function PetModels.clips(model: Model): { [string]: number }
	local animated = rigs[model]
	local result = {}
	if animated then
		for name, clip in animated.clips do
			result[name] = clip.length
		end
	end
	return result
end

local ZERO6 = { 0, 0, 0, 0, 0, 0 }
local WAVE_AXES = { "x", "y", "z", "px", "py", "pz" }

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Lo que suman los clips en un instante, ya con su peso: giro de cada hueso (grados; "Body" lleva
-- además el desplazamiento), ondas, ritmo de las patas y factor de los senos de cada hueso.
type Wave = { bone: string, amplitude: { number }, speed: number, phase: number, lag: number, time: number }
type Mix = {
	bones: { [string]: { number } },
	waves: { Wave },
	gait: number?,
	gaitWeight: number,
	amp: { [string]: number },
}

local function addClip(mix: Mix, clip: Clip, time: number, weight: number)
	local keys = clip.keys
	local t = if clip.loop then time % clip.length else math.clamp(time, 0, clip.length)
	local index = 1
	for i, key in keys do
		if key.t <= t then
			index = i
		end
	end
	local a = keys[index]
	local b = keys[index + 1] or a
	local alpha = if b.t > a.t then (t - a.t) / (b.t - a.t) else 0
	local s = if a.linear then alpha else alpha * alpha * (3 - 2 * alpha)

	local seen: { [string]: boolean } = {}
	for _, key in { a, b } do
		for name, value in key do
			if type(value) == "table" and name ~= "amp" and name ~= "waves" and not seen[name] then
				seen[name] = true
				local from = a[name] or ZERO6
				local to = b[name] or ZERO6
				local total = mix.bones[name] or { 0, 0, 0, 0, 0, 0 }
				for c = 1, 6 do
					total[c] += lerp(from[c] or 0, to[c] or 0, s) * weight
				end
				mix.bones[name] = total
			end
		end
	end

	local wavesA, wavesB = a.waves or {}, b.waves or {}
	local waveSeen: { [string]: boolean } = {}
	for _, list in { wavesA, wavesB } do
		for bone in list do
			if not waveSeen[bone] then
				waveSeen[bone] = true
				local wa, wb = wavesA[bone], wavesB[bone]
				local shape = wa or wb
				local amplitude = table.create(6, 0)
				for c, axis in WAVE_AXES do
					local from = if wa then wa[axis] or 0 else 0
					local to = if wb then wb[axis] or 0 else 0
					amplitude[c] = lerp(from, to, s) * weight
				end
				table.insert(mix.waves, {
					bone = bone,
					amplitude = amplitude,
					speed = shape.speed or 1,
					phase = shape.phase or 0,
					lag = shape.lag or 0.7,
					time = time,
				})
			end
		end
	end

	if a.gait or b.gait then
		mix.gait = lerp(a.gait or b.gait, b.gait or a.gait, s)
		mix.gaitWeight = weight
	end

	local ampA, ampB = a.amp or {}, b.amp or {}
	local ampSeen: { [string]: boolean } = {}
	for _, list in { ampA, ampB } do
		for bone in list do
			if not ampSeen[bone] then
				ampSeen[bone] = true
				local value = lerp(ampA[bone] or 1, ampB[bone] or 1, s)
				mix.amp[bone] = (mix.amp[bone] or 1) * lerp(1, value, weight)
			end
		end
	end
end

-- Giro de un hueso en este instante (pose más ondas), con el retraso de su puesto en la cadena.
local function boneAngles(mix: Mix, bone: string, lag: number): { number }?
	local base = mix.bones[bone]
	local result: { number }? = if base then table.clone(base) else nil
	for _, wave in mix.waves do
		if wave.bone == bone then
			local total = result or { 0, 0, 0, 0, 0, 0 }
			local value = math.sin(wave.time * wave.speed + wave.phase - lag * wave.lag)
			for c = 1, 6 do
				total[c] += wave.amplitude[c] * value
			end
			result = total
		end
	end
	return result
end

-- Primero gira a un lado (Y), luego cabecea (X) ya girado y luego se ladea (Z): una cabeza que mira
-- a la izquierda y abajo no se tuerce.
local function rotation(angles: { number }): CFrame
	return CFrame.fromEulerAnglesYXZ(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
end

-- Mueve las partes animadas según el tiempo; "moving" (0 a 1) indica cuánto anda el dueño.
-- "layers": clips que suenan encima (ver Layer). "stride": reloj de las patas que andan (por
-- defecto, "time"), que va más deprisa cuando el dueño corre. Todas a la vez con BulkMoveTo: con un
-- centenar de piezas articuladas por mascota (alas de plumas sueltas, patas de dos tramos) es mucho
-- más barato que cambiar el CFrame de cada una. "bend" (radianes, + a la izquierda) es cuánto está
-- girando la mascota: las que lo tienen doblan el cuerpo hacia la curva (cadera y cabeza de los
-- felinos voxel).
function PetModels.animate(
	model: Model,
	time: number,
	moving: number,
	layers: { Layer }?,
	stride: number?,
	bend: number?
)
	local animated = rigs[model]
	if not animated then
		return
	end
	local mix: Mix = { bones = {}, waves = {}, gait = nil, gaitWeight = 0, amp = {} }
	local around = Vector3.zero
	for _, layer in layers or {} do
		local clip = animated.clips[layer.clip]
		if clip and layer.weight > 0 then
			addClip(mix, clip, layer.time, layer.weight)
			around = clip.around or around
		end
	end
	if mix.gait then
		moving = lerp(moving, mix.gait, mix.gaitWeight)
	end
	local scale = animated.scale
	local strideTime = stride or time

	-- El cuerpo entero: todo lo demás cuelga de él.
	local body = CFrame.identity
	local bodyAngles = boneAngles(mix, "Body", 0)
	if bodyAngles then
		local center = around * scale
		body = CFrame.new(Vector3.new(bodyAngles[4], bodyAngles[5], bodyAngles[6]) * scale)
			* CFrame.new(center)
			* rotation(bodyAngles)
			* CFrame.new(-center)
	end

	local pivot = model:GetPivot()
	local joints = animated.joints
	-- Las piezas fijas se mueven mientras un clip mueve el cuerpo, y una vez más al acabar (para
	-- devolverlas a su sitio).
	local moveStatics = bodyAngles ~= nil or animated.bodyMoved
	animated.bodyMoved = bodyAngles ~= nil
	-- La cadera fija se mueve mientras gira o mientras se mueve el cuerpo, y una vez más al acabar.
	local bendAngle = bend or 0
	local bendRig = animated.bend
	local bending = math.abs(bendAngle) > 0.002
	local moveBend = bendRig ~= nil and (bending or animated.bendMoved or moveStatics)
	animated.bendMoved = bending
	local count = #joints
		+ (if moveStatics then #animated.statics else 0)
		+ (if moveBend and bendRig then #bendRig.parts else 0)
	local parts = table.create(count)
	local frames = table.create(count)
	for i, item in joints do
		local bone = item.bone
		local factor = (if item.gait then moving else 1) * (if bone then mix.amp[bone] or 1 else 1)
		local clock = if item.gait then strideTime else time
		local angle = (math.sin(clock * item.speed + item.phase) * item.amplitude + item.bias) * factor
		local turn = CFrame.fromAxisAngle(item.axis, angle)
		local angles = if bone then boneAngles(mix, bone, item.lag) else nil
		if angles then
			turn = rotation(angles) * turn
		end
		if item.bend ~= 0 and bendAngle ~= 0 then
			turn = CFrame.Angles(0, bendAngle * item.bend, 0) * turn
		end
		local parent = item.parent
		item.world = (if parent then parent.world else body) * item.hinge * turn * item.hinge:Inverse()
		parts[i] = item.part
		frames[i] = pivot * item.world * item.hinge * item.offset
	end
	if moveStatics then
		local offset = #joints
		for i, part in animated.statics do
			parts[offset + i] = part
			frames[offset + i] = pivot * body * animated.rest[i]
		end
	end
	if moveBend and bendRig then
		local frame = pivot
			* body
			* bendRig.hinge
			* CFrame.Angles(0, bendAngle * bendRig.factor, 0)
			* bendRig.hinge:Inverse()
		local offset = #parts
		for i, part in bendRig.parts do
			parts[offset + i] = part
			frames[offset + i] = frame * bendRig.rest[i]
		end
	end
	if model:IsDescendantOf(workspace) then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for i, part in parts do
			part.CFrame = frames[i]
		end
	end
end

return PetModels
