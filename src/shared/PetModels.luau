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

-- Felino en estilo voxel (bloques grandes, como la referencia del ocelote en docs/img): cuerpo de
-- caja con el vientre claro, paletillas y ancas en bloque, cabeza cúbica con hocico cuadrado, orejas
-- oscuras, patas en columna con dedos marcados y cola recta por tramos. Mismos huesos y medidas
-- ("dims") que "cat", así que usa los mismos clips. Medidas en celdas, con el suelo en y = 0.
local function voxelCat(rig: Rig, coat: Color3, options: CatOptions)
	local crystal = options.crystal == true
	local slim = options.slim == true
	local spots = options.spots
	local material = if crystal then Enum.Material.Glacier else Enum.Material.SmoothPlastic
	local light = coat:Lerp(WHITE, 0.45)
	local pale = coat:Lerp(WHITE, 0.22)
	local belly = if spots and not crystal then coat:Lerp(WHITE, 0.78) else coat:Lerp(WHITE, 0.18)
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
	local muzzleColor = if spots then light else coat:Lerp(WHITE, 0.15)
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
		flat(headParts, "Eye", eye, -Vector3.zAxis, Vector3.xAxis, Vector2.new(1.5 * s, 0.8 * s), options.eyeColor, 0.1).Material = if crystal
			then Enum.Material.Neon
			else Enum.Material.SmoothPlastic
		flat(
			headParts,
			"Pupil",
			eye,
			-Vector3.zAxis,
			Vector3.xAxis,
			Vector2.new(0.35 * s, 0.8 * s),
			if crystal then Color3.fromRGB(20, 60, 120) else BLACK,
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
	local paw = coat:Lerp(WHITE, if spots then 0.32 else 0.12)
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
				dark
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

	if crystal then
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
	local skullPart = box(headParts, "Head", head, skull, headColor)
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
		local part = box(nil, "Ear", Vector3.new(x, earTop - ear.Y / 2, earZ), ear, o.ears or headColor)
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
			box(
				upper,
				"Shoulder",
				Vector3.new(side * (bodyW / 2 - 0.85), bottom + bodyH * 0.42, z - 0.2),
				Vector3.new(2, bodyH * 0.66, 3.4),
				shoulderColor
			)
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
		halfHeight = bodyH / 2 * VOXEL,
		halfWidth = (bodyW / 2 + 0.3) * VOXEL,
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
			snout = Vector3.new(3.8, 2.8, 3.2),
			neck = 3.6,
			ear = Vector3.new(0.8, 3.2, 2.6),
			tail = { Vector3.new(0, 0.3, 1), Vector3.new(0, 0.05, 1), Vector3.new(0, -0.1, 1) },
			tailSegment = 2.1,
			tailWidth = 2.4,
			tailTaper = 0.5,
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
			nose = Color3.fromRGB(40, 32, 30),
			head = black,
			ears = black,
			muzzle = black,
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
	JaguarCristal = function(rig, color)
		local glow = Color3.fromRGB(80, 200, 255)
		local options: CatOptions = {
			spots = glow,
			crystal = true,
			eyeColor = Color3.fromRGB(120, 235, 255),
			earSize = 0.36,
		}
		felid(rig, color, options)
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
		light.Color = color
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = heart
		local body = rig.model:FindFirstChild("Body")
		if body then
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

		-- Patas cortas con dos dedos delante (con una rendija entre ellos) y uno detrás.
		for _, side in { -1, 1 } do
			local x = side * 1.6
			box(nil, "Leg", Vector3.new(x, 2.4, 0.6), Vector3.new(1.2, 2.8, 1.2), feet)
			box(nil, "Toe", Vector3.new(x, 0.4, -0.4), Vector3.new(1.8, 0.8, 2.6), feet)
			box(nil, "ToeGap", Vector3.new(x, 0.45, -1.2), Vector3.new(0.2, 0.75, 1.1), feet:Lerp(BLACK, 0.5))
			box(nil, "Toe", Vector3.new(x, 0.4, 1.7), Vector3.new(0.9, 0.8, 1.4), feet)
		end

		-- Cuerpo en tres bloques que se estrechan hacia el cuello.
		box(nil, "Belly", Vector3.new(0, 6.5, 0.8), Vector3.new(7.4, 5, 7.6), color)
		box(nil, "Body", Vector3.new(0, 11.5, 0), Vector3.new(7.8, 5, 7.4), color)
		box(nil, "Shoulders", Vector3.new(0, 15.5, 0), Vector3.new(7, 3, 7.4), color)
		-- Manto azulado en la espalda, en dos escalones: sin él, de espaldas era una losa negra.
		box(nil, "Mantle", Vector3.new(0, 13.4, 3.85), Vector3.new(5.6, 5.4, 0.4), color:Lerp(sheen, 0.5))
		box(nil, "Mantle", Vector3.new(0, 11.4, 4.1), Vector3.new(4.4, 3, 0.4), sheen)
		-- Babero crema por delante y por los lados del pecho, con el borde de abajo amarillo.
		box(nil, "Bib", Vector3.new(0, 13, -3.85), Vector3.new(6.2, 6.5, 0.5), cream)
		box(nil, "BibEdge", Vector3.new(0, 9.4, -3.9), Vector3.new(6.4, 1.2, 0.6), yellow)
		for _, side in { -1, 1 } do
			box(nil, "BibSide", Vector3.new(side * 3.95, 11.8, -2.4), Vector3.new(0.2, 4.4, 2.8), cream)
		end

		-- Cabeza: bloque negro con la garganta crema, mejillas amarillas y el ojo en su cuadro rojo.
		local head: { BasePart } = {}
		box(head, "Head", Vector3.new(0, 19, -1), Vector3.new(6.4, 6, 6.4), color)
		box(head, "Crown", Vector3.new(0, 22.4, -0.6), Vector3.new(5.4, 0.8, 5), color)
		box(head, "Throat", Vector3.new(0, 16.6, -4.35), Vector3.new(5.4, 1.8, 0.5), cream)
		for _, side in { -1, 1 } do
			box(head, "Cheek", Vector3.new(side * 3.25, 17.8, -2.6), Vector3.new(0.3, 2.6, 3.2), yellow)
			box(head, "EyeSkin", Vector3.new(side * 3.3, 20, -2.4), Vector3.new(0.3, 2.4, 2.6), red)
			box(head, "Eye", Vector3.new(side * 3.45, 20, -2.5), Vector3.new(0.3, 1.1, 1.1), Color3.fromRGB(25, 30, 45))
			box(head, "Glint", Vector3.new(side * 3.62, 20.25, -2.75), Vector3.new(0.1, 0.35, 0.35), WHITE)
		end
		-- Pico: base amarilla, mandíbula de arriba naranja con la franja oscura y la cresta en escalón,
		-- la de abajo más rojiza, la comisura oscura entre las dos y la punta roja que baja en gancho.
		box(head, "BeakBase", Vector3.new(0, 19, -4.7), Vector3.new(4.6, 4.8, 1.2), yellow)
		box(head, "Beak", Vector3.new(0, 19.6, -9.8), Vector3.new(4.2, 3.2, 9.6), orange)
		box(head, "BeakRidge", Vector3.new(0, 21.4, -8.4), Vector3.new(3.4, 0.6, 6.4), Color3.fromRGB(255, 170, 40))
		box(head, "BeakStripe", Vector3.new(0, 19.6, -11), Vector3.new(4.35, 1.2, 5.4), deep)
		box(head, "LowerBeak", Vector3.new(0, 17.2, -9.2), Vector3.new(3.6, 1.6, 8.4), deep)
		box(head, "Gape", Vector3.new(0, 18.05, -9.4), Vector3.new(4.3, 0.25, 8.6), Color3.fromRGB(60, 25, 15))
		box(head, "BeakTip", Vector3.new(0, 18.8, -15.3), Vector3.new(3.6, 3.2, 1.8), red)
		box(head, "BeakHook", Vector3.new(0, 16.9, -15.6), Vector3.new(3, 1.6, 1.6), red:Lerp(BLACK, 0.15))
		v.swing(head, Vector3.new(0, 16, -0.5), Vector3.xAxis, 0.1, 3, 0, false)

		-- Alas abiertas en escalones, con una fila de cobertoras encima y las remeras azuladas detrás.
		for _, side in { -1, 1 } do
			voxelWing(v, side, Vector3.new(side * 3.6, 14.5, 0.2), {
				{ center = Vector3.new(2, 0.1, 0.2), size = Vector3.new(4.6, 1.6, 5.6), color = color },
				{ center = Vector3.new(5.6, 0, 0.8), size = Vector3.new(3.6, 1.2, 4.8), color = color },
				{ center = Vector3.new(8.6, -0.1, 1.4), size = Vector3.new(3.2, 1, 3.8), color = color },
				{ center = Vector3.new(3.4, 0.9, -1.6), size = Vector3.new(6, 0.4, 2), color = sheen },
				{ center = Vector3.new(3, -0.3, 3.9), size = Vector3.new(4.6, 0.8, 2), color = sheen },
				{ center = Vector3.new(6.8, -0.3, 4.2), size = Vector3.new(3.6, 0.8, 2.6), color = sheen },
				{ center = Vector3.new(10.2, -0.3, 4), size = Vector3.new(2.8, 0.7, 3.4), color = sheen },
			}, 0.7, 14)
		end

		-- Cola cuadrada que cae hacia atrás, con las cobertoras encima y la punta azulada.
		local tailParts: { BasePart } = {}
		v.beam(
			tailParts,
			"TailCovert",
			Vector3.new(0, 8.6, 3.4),
			Vector3.new(0, 5.2, 6.6),
			Vector2.new(5.4, 1.4),
			color
		)
		v.beam(tailParts, "Tail", Vector3.new(0, 7, 4), Vector3.new(0, 1.6, 8.6), Vector2.new(4.8, 1.2), color)
		v.beam(tailParts, "TailTip", Vector3.new(0, 2.4, 7.9), Vector3.new(0, 0.6, 9.6), Vector2.new(4.4, 1.1), sheen)
		v.swing(tailParts, Vector3.new(0, 7, 3.6), Vector3.xAxis, 0.15, 6, 1, false)
		rig.family = "Bird"
		return "Fly"
	end,

	-- Colibrí voxel (docs/img/Colibri.jfif): verde con la gorguera morada, pecho lila que pasa a cian,
	-- antifaz verde oscuro, pico finísimo y largo, alas verdes con las puntas azules en escalones,
	-- cola en abanico de bandas verdes y azules, y patitas moradas.
	Colibri = function(rig, color)
		local v = voxelKit(rig, Vector3.new(0, 7.5, 0))
		local box = v.box
		local light = color:Lerp(Color3.fromRGB(150, 255, 120), 0.35)
		local dark = color:Lerp(BLACK, 0.45)
		local teal = Color3.fromRGB(35, 165, 185)
		local blue = Color3.fromRGB(30, 120, 215)
		local purple = Color3.fromRGB(120, 70, 210)
		local lilac = Color3.fromRGB(150, 130, 230)
		local feet = Color3.fromRGB(85, 70, 105)

		for _, side in { -1, 1 } do
			local x = side * 1.1
			box(nil, "Leg", Vector3.new(x, 1.3, 0.4), Vector3.new(0.8, 1.6, 0.8), feet)
			box(nil, "Toe", Vector3.new(x, 0.3, -0.2), Vector3.new(0.9, 0.6, 1.8), feet)
		end
		box(nil, "Belly", Vector3.new(0, 3.8, 0.4), Vector3.new(4.8, 3.6, 5), color)
		box(nil, "Body", Vector3.new(0, 7.6, 0), Vector3.new(5.4, 4.2, 5.4), color)
		-- Por delante, de arriba abajo: gorguera morada (que rodea el cuello), pecho lila y vientre cian.
		box(nil, "Breast", Vector3.new(0, 7, -2.85), Vector3.new(4.4, 2.4, 0.5), lilac)
		box(nil, "Breast", Vector3.new(0, 5.6, -2.85), Vector3.new(3.4, 1.2, 0.5), lilac:Lerp(teal, 0.5))
		box(nil, "BellyFront", Vector3.new(0, 4, -2.2), Vector3.new(2.8, 2.6, 0.5), teal)
		-- Franja azulada en la espalda, de lado a lado: más estrecha parecía una mochila.
		box(nil, "Mantle", Vector3.new(0, 8.2, 2.8), Vector3.new(5.5, 2.6, 0.3), teal)

		local head: { BasePart } = {}
		box(head, "Head", Vector3.new(0, 11.6, -0.8), Vector3.new(4.6, 4, 4.6), color)
		box(head, "Crown", Vector3.new(0, 13.75, -0.6), Vector3.new(3.8, 0.5, 3.6), light)
		box(head, "Gorget", Vector3.new(0, 9.4, -2.95), Vector3.new(4.2, 2.2, 0.6), purple)
		for _, side in { -1, 1 } do
			box(head, "GorgetSide", Vector3.new(side * 2.75, 9, -1.6), Vector3.new(0.3, 1.8, 2.4), purple)
			box(head, "Mask", Vector3.new(side * 2.35, 11.7, -1.3), Vector3.new(0.3, 1.4, 3.4), dark)
			box(
				head,
				"Eye",
				Vector3.new(side * 2.5, 11.9, -1.6),
				Vector3.new(0.3, 1.1, 1.1),
				Color3.fromRGB(25, 20, 25)
			)
			box(head, "Glint", Vector3.new(side * 2.66, 12.15, -1.85), Vector3.new(0.1, 0.35, 0.35), WHITE)
		end
		-- Pico: una hilera finísima y recta, algo más gruesa en la base.
		local beak = Color3.fromRGB(30, 60, 60)
		box(head, "BeakBase", Vector3.new(0, 11.4, -3.6), Vector3.new(1, 0.9, 1.2), beak)
		box(head, "Beak", Vector3.new(0, 11.4, -7.1), Vector3.new(0.6, 0.6, 7.6), beak)
		v.swing(head, Vector3.new(0, 9.6, -0.5), Vector3.xAxis, 0.1, 3, 0, false)

		for _, side in { -1, 1 } do
			voxelWing(v, side, Vector3.new(side * 2.7, 8.4, 0.6), {
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
			}, 0.9, 45)
		end

		-- Cola en abanico: cinco plumas que bajan hacia atrás, en bandas verde, azul, verde y azul.
		local tailParts: { BasePart } = {}
		local rump = Vector3.new(0, 3, 2.6)
		local bands = { { 3.4, color }, { 2, blue }, { 1.6, light }, { 1.6, blue } }
		for i = -2, 2 do
			local direction = Vector3.new(i * 0.26, -0.8, 0.75).Unit
			local reach = 1 - math.abs(i) * 0.12
			local from = rump + Vector3.new(i * 0.8, -math.abs(i) * 0.05, 0)
			for _, band in bands do
				local to = from + direction * band[1] * reach
				v.beam(tailParts, "TailFeather", from, to, Vector2.new(1.7, 0.5), band[2])
				from = to
			end
		end
		v.swing(tailParts, rump, Vector3.xAxis, 0.15, 6, 1, false)
		return "Hover"
	end,

	-- Rana dardo voxel (docs/img/Rana dardo.jfif): azul con motas negras, lomo arqueado que sube hacia
	-- atrás, ojos negros saltones en bloque, boca en raya, vientre más claro, patas de delante finas
	-- y las de atrás plegadas en Z, con dedos planos y ventosas en la punta. Va a saltos.
	Rana = function(rig, color)
		local v = voxelKit(rig, Vector3.new(0, 4, 0))
		local box = v.box
		local belly = color:Lerp(WHITE, 0.25)
		local navy = color:Lerp(BLACK, 0.55)
		local legColor = color:Lerp(BLACK, 0.12)
		local spot = Color3.fromRGB(18, 18, 24)

		-- Cuerpo: la parte de delante algo más alta (está sentada sobre las patas de delante), el lomo
		-- y la joroba de la cadera encima, y la trasera redondeada que acaba de golpe.
		box(nil, "Body", Vector3.new(0, 3.2, 3.5), Vector3.new(8, 3.2, 5), color)
		box(nil, "Chest", Vector3.new(0, 3.9, -1.5), Vector3.new(8, 3.4, 5), color)
		box(nil, "Back", Vector3.new(0, 6.1, 1.2), Vector3.new(7, 1.8, 8.4), color)
		box(nil, "Hump", Vector3.new(0, 7.4, 2.4), Vector3.new(5.4, 1.2, 5), color)
		box(nil, "Rump", Vector3.new(0, 3.8, 6.4), Vector3.new(6, 3.4, 1), color)
		box(nil, "Belly", Vector3.new(0, 1.5, 1.6), Vector3.new(6.6, 0.3, 8.6), belly)

		-- Cabeza ancha y plana con el hocico en escalón, la boca en raya oscura alrededor y la garganta
		-- clara.
		box(nil, "Head", Vector3.new(0, 5.2, -5.4), Vector3.new(7.6, 3.6, 4.4), color)
		box(nil, "Snout", Vector3.new(0, 4.9, -8), Vector3.new(6, 2.6, 1.2), color)
		box(nil, "Mouth", Vector3.new(0, 4.3, -6.075), Vector3.new(7.75, 0.3, 5.15), navy)
		box(nil, "Throat", Vector3.new(0, 3.4, -5.6), Vector3.new(6.6, 1, 4.6), belly)
		for _, side in { -1, 1 } do
			-- Ojo negro saltón sobre su bulto azul, con un brillo gris en la cara de delante.
			box(nil, "EyeBump", Vector3.new(side * 2.7, 7.2, -5.6), Vector3.new(2.6, 1, 2.6), color)
			box(nil, "Eye", Vector3.new(side * 2.75, 8, -5.8), Vector3.new(2, 1.8, 2), spot)
			box(
				nil,
				"Glint",
				Vector3.new(side * 3.05, 8.4, -6.85),
				Vector3.new(0.6, 0.6, 0.1),
				Color3.fromRGB(95, 100, 115)
			)
			box(nil, "Nostril", Vector3.new(side * 0.9, 5.6, -8.62), Vector3.new(0.5, 0.4, 0.1), navy)
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
				{ Vector3.new(1, 4.2, 6.95), Vector3.new(1, 1, 0.2) },
				{ Vector3.new(-1.4, 3, 6.95), Vector3.new(0.8, 1, 0.2) },
				{ Vector3.new(-1.75, 3.6, 6.95), Vector3.new(0.6, 0.4, 0.2) },
			}
		do
			box(nil, "Spot", mark[1], mark[2], spot)
		end

		-- Dedo plano con su ventosa en la punta, de "from" en la dirección "direction" (en el suelo).
		local function finger(list: { BasePart }, from: Vector3, direction: Vector3, length: number, pad: Color3)
			local to = from + direction.Unit * length
			v.beam(list, "Toe", from, to, Vector2.new(0.5, 0.45), legColor)
			box(list, "ToePad", to + Vector3.new(0, 0.1, 0), Vector3.new(0.8, 0.65, 0.8), pad)
		end
		for _, side in { -1, 1 } do
			-- Pata de delante delgada y recta, con la mano de tres dedos abiertos.
			local front: { BasePart } = {}
			box(front, "FrontLeg", Vector3.new(side * 4.4, 2.3, -4.4), Vector3.new(1.2, 3.6, 1.2), legColor)
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
			-- Raya negra en el muslo, como en la referencia.
			box(back, "Spot", Vector3.new(side * 6.05, 3.3, 1.6), Vector3.new(0.2, 0.8, 1.6), spot)
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
			v.swing(back, Vector3.new(side * 3.6, 3.4, 4.2), Vector3.xAxis, 0.22, 12, -math.pi / 2, true, 0.22)
			v.swing(front, Vector3.new(side * 3.6, 3.8, -3.6), Vector3.xAxis, 0.25, 12, -math.pi / 2, true, 0.25)
		end
		return "Hop"
	end,

	-- Tortuga verde voxel (docs/img/Tortuga verde.jfif): caparazón ancho y bajo en capas que se
	-- estrechan hacia arriba, con placas verde oliva, amarillas y marrones y el borde marrón oscuro;
	-- cabeza que asoma con escamas amarillas, aletas de delante largas en escalones y las de atrás
	-- cortas. Rema con las aletas al andar.
	Tortuga = function(rig, color)
		local v = voxelKit(rig, Vector3.new(0, 4, 0))
		local box = v.box
		local skin = Color3.fromRGB(55, 110, 40)
		local skinDark = skin:Lerp(BLACK, 0.25)
		local scale = Color3.fromRGB(170, 155, 45)
		local olive = color:Lerp(Color3.fromRGB(110, 115, 25), 0.6)
		local yellow = Color3.fromRGB(150, 140, 40)
		local brown = Color3.fromRGB(110, 72, 35)
		local rim = Color3.fromRGB(85, 55, 30)
		local plastron = Color3.fromRGB(170, 155, 70)

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
		box(nil, "Shell", Vector3.new(0, 7.4, 0.5), Vector3.new(6, 0.8, 9), olive:Lerp(yellow, 0.3))
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

		-- Cabeza que asoma con el cuello, el hocico romo en escalón, la boca en raya y escamas amarillas.
		local head: { BasePart } = {}
		box(head, "Neck", Vector3.new(0, 3.4, -11), Vector3.new(4, 2.8, 3), skin)
		box(head, "Head", Vector3.new(0, 4, -14), Vector3.new(5, 3.8, 4.6), skin)
		box(head, "Snout", Vector3.new(0, 3.6, -16.8), Vector3.new(4, 2.8, 1.2), skin)
		box(head, "Mouth", Vector3.new(0, 3, -16.3), Vector3.new(4.1, 0.25, 2.3), skinDark:Lerp(BLACK, 0.4))
		for _, side in { -1, 1 } do
			box(head, "Eye", Vector3.new(side * 2.55, 4.6, -15), Vector3.new(0.2, 1, 1), Color3.fromRGB(45, 20, 20))
			box(head, "Glint", Vector3.new(side * 2.62, 4.85, -15.25), Vector3.new(0.1, 0.35, 0.35), WHITE)
			box(head, "Nostril", Vector3.new(side * 0.8, 4.4, -17.45), Vector3.new(0.4, 0.4, 0.1), skinDark)
			for _, spot in { { 3.6, -13 }, { 5, -12.6 }, { 3.4, -14.3 }, { 5.3, -13.9 } } do
				box(head, "Scale", Vector3.new(side * 2.55, spot[1], spot[2]), Vector3.new(0.2, 0.8, 0.8), scale)
			end
		end
		for _, spot in { { -1, -13 }, { 1, -13.4 }, { 0, -14.6 }, { -1.3, -15.4 }, { 1.2, -15.7 }, { 0, -12.1 } } do
			box(head, "Scale", Vector3.new(spot[1], 5.95, spot[2]), Vector3.new(0.8, 0.2, 0.8), scale)
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
			v.swing(front, Vector3.new(side * 6, 2.4, -6), Vector3.yAxis, 0.3 * side, 5, 0, true)

			local back: { BasePart } = {}
			box(back, "Flipper", Vector3.new(side * 5.5, 1.2, 10.8), Vector3.new(3, 1, 3), skin)
			box(back, "Flipper", Vector3.new(side * 6.8, 0.7, 12.6), Vector3.new(2.6, 0.8, 2.6), skin)
			box(back, "Scale", Vector3.new(side * 5.5, 1.8, 10.6), Vector3.new(0.8, 0.2, 0.8), scale)
			v.swing(back, Vector3.new(side * 4.5, 1.6, 9.5), Vector3.yAxis, -0.25 * side, 5, math.pi, true)
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
		local yellow = Color3.fromRGB(245, 195, 30)
		local green = Color3.fromRGB(70, 150, 60)
		local blue = Color3.fromRGB(30, 85, 210)
		local deepBlue = Color3.fromRGB(25, 50, 150)
		local horn = Color3.fromRGB(235, 228, 215)
		local feet = Color3.fromRGB(125, 112, 112)

		-- Patas: dos dedos delante (con una rendija) y dos detrás, para trepar.
		for _, side in { -1, 1 } do
			local x = side * 1.5
			box(nil, "Leg", Vector3.new(x, 2.9, 0.6), Vector3.new(1.2, 3.8, 1.2), feet)
			box(nil, "Toe", Vector3.new(x, 0.4, -0.5), Vector3.new(1.8, 0.8, 2.8), feet)
			box(nil, "ToeGap", Vector3.new(x, 0.45, -1.4), Vector3.new(0.2, 0.75, 1.1), feet:Lerp(BLACK, 0.5))
			box(nil, "Toe", Vector3.new(x, 0.4, 1.8), Vector3.new(1.6, 0.8, 1.6), feet)
			box(nil, "Claw", Vector3.new(x, 0.3, -2.05), Vector3.new(1.8, 0.6, 0.3), Color3.fromRGB(50, 45, 45))
		end

		-- Cuerpo alto y estrecho en cuatro bloques que se estrechan hacia el cuello, y lomo en dos
		-- escalones (de espaldas no es una losa). Un panel más oscuro en el pecho parecía un delantal.
		box(nil, "Belly", Vector3.new(0, 7.2, 0.8), Vector3.new(6.4, 5.6, 6.6), color)
		box(nil, "Body", Vector3.new(0, 12.6, 0), Vector3.new(7, 5.6, 6.6), color)
		box(nil, "Shoulders", Vector3.new(0, 16.8, 0), Vector3.new(6.2, 3, 6.4), color)
		box(nil, "Neck", Vector3.new(0, 19.4, -0.4), Vector3.new(5.2, 2.6, 5.4), color)
		box(nil, "Mantle", Vector3.new(0, 14, 3.45), Vector3.new(5.4, 6, 0.4), deep)
		box(nil, "Mantle", Vector3.new(0, 9.4, 4.25), Vector3.new(4, 2.6, 0.4), deep:Lerp(BLACK, 0.12))

		-- Cabeza: bloque rojo y cara blanca a los lados con el ojo negro y su brillo (una hilera de
		-- plumitas rojas bajo el ojo parecía una boca).
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
		for _, side in { -1, 1 } do
			box(head, "Face", Vector3.new(side * 3.15, 18.4, -2.3) + up, Vector3.new(0.3, 3.8, 3.6), WHITE)
			box(head, "FaceFront", Vector3.new(side * 2, 17.6, -3.75) + up, Vector3.new(2.2, 2.4, 0.3), WHITE)
			box(head, "Eye", Vector3.new(side * 3.35, 19.4, -2.1) + up, Vector3.new(0.2, 1.3, 1.3), BLACK)
			box(head, "Glint", Vector3.new(side * 3.47, 19.7, -2.35) + up, Vector3.new(0.1, 0.45, 0.45), WHITE)
		end
		-- Pico enorme: mandíbula de arriba clara en tres escalones que bajan en gancho con la punta
		-- oscura, y la de abajo negra, más ancha que el gancho para que se vea de frente.
		box(head, "BeakBase", Vector3.new(0, 19.2, -4.3) + up, Vector3.new(4, 3.6, 1.6), horn)
		box(head, "Beak", Vector3.new(0, 19, -5.9) + up, Vector3.new(3.4, 3.2, 2), horn)
		box(head, "BeakHook", Vector3.new(0, 16.9, -6.7) + up, Vector3.new(2.6, 2.4, 1.6), horn)
		box(head, "BeakTip", Vector3.new(0, 15.4, -6.6) + up, Vector3.new(1.6, 1, 1.2), Color3.fromRGB(60, 58, 62))
		box(head, "LowerBeak", Vector3.new(0, 16.3, -4.8) + up, Vector3.new(3.8, 2.4, 2.8), BLACK)
		v.swing(head, Vector3.new(0, 18.6, -0.5), Vector3.xAxis, 0.1, 3, 0, false)

		-- Alas largas abiertas: brazo rojo, banda amarilla con el borde verde y remeras azules que se
		-- oscurecen hacia la punta.
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
			}, 0.7, 12)
		end

		-- Cola larguísima y en punta: cobertoras rojas, la pluma del centro roja con la punta azul y
		-- dos azules más cortas a los lados.
		local tailParts: { BasePart } = {}
		v.beam(tailParts, "TailCovert", Vector3.new(0, 9.4, 3.4), Vector3.new(0, 6.2, 8), Vector2.new(4.6, 1.4), color)
		v.beam(tailParts, "Tail", Vector3.new(0, 7.6, 4), Vector3.new(0, 1.2, 18), Vector2.new(2.4, 1), color)
		v.beam(tailParts, "TailTip", Vector3.new(0, 1.6, 17.2), Vector3.new(0, 0.4, 21), Vector2.new(1.6, 0.9), blue)
		for _, side in { -1, 1 } do
			v.beam(
				tailParts,
				"TailSide",
				Vector3.new(side * 1.5, 7.4, 4.2),
				Vector3.new(side * 1.9, 2.6, 13.4),
				Vector2.new(1.8, 0.9),
				blue
			)
		end
		v.swing(tailParts, Vector3.new(0, 7.6, 3.6), Vector3.xAxis, 0.15, 6, 1, false)
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
		v.swing(head, Vector3.new(0, 12.6, -5.5), Vector3.zAxis, 0.15, 0.6, 0, false, nil, "Head")

		-- Garra en gancho: un bloque hacia delante y la punta que baja.
		local function hook(list: { BasePart }, base: Vector3, length: number)
			box(list, "Claw", base + Vector3.new(0, 0, -length / 2), Vector3.new(0.6, 0.6, length), claw)
			box(list, "ClawTip", base + Vector3.new(0, -0.6, -length + 0.3), Vector3.new(0.6, 1.2, 0.6), clawTip)
		end
		for _, side in { -1, 1 } do
			-- Brazo largo que baja hacia delante hasta la mano, con un mechón en el codo.
			local arm: { BasePart } = {}
			v.beam(
				arm,
				"UpperArm",
				Vector3.new(side * 5.6, 14.5, -3),
				Vector3.new(side * 6, 7.5, -8),
				Vector2.new(3.2, 3.2),
				limb
			)
			v.beam(
				arm,
				"Forearm",
				Vector3.new(side * 6, 7.8, -8),
				Vector3.new(side * 6.1, 1.6, -12.6),
				Vector2.new(3, 3),
				limb
			)
			box(arm, "ElbowShag", Vector3.new(side * 6.2, 7.8, -7.2), Vector3.new(3.2, 2.6, 3), shag)
			box(arm, "Hand", Vector3.new(side * 6.1, 1.1, -13), Vector3.new(2.8, 1.6, 2.8), shag)
			for k = -1, 1 do
				hook(arm, Vector3.new(side * 6.1 + k * 0.85, 1.2, -14.2), 2)
			end
			v.swing(arm, Vector3.new(side * 5.4, 14, -3), Vector3.xAxis, 0.5, 4, if side < 0 then 0 else math.pi, true)

			-- Pata de atrás más corta, con tres garras.
			local leg: { BasePart } = {}
			box(leg, "Thigh", Vector3.new(side * 4.8, 8.6, 5.4), Vector3.new(3, 4.4, 3.8), fur)
			box(leg, "Shin", Vector3.new(side * 5, 4.2, 5.2), Vector3.new(2.6, 5, 2.6), fur)
			box(leg, "Foot", Vector3.new(side * 5, 1, 4.6), Vector3.new(2.6, 1.6, 3), dark)
			for k = -1, 1 do
				hook(leg, Vector3.new(side * 5 + k * 0.8, 1.1, 3.2), 1.4)
			end
			v.swing(leg, Vector3.new(side * 4, 10, 5.5), Vector3.xAxis, 0.4, 4, if side < 0 then math.pi else 0, true)
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

-- Perros: de momento, el galope del felino (sus clips propios llegan con sus animaciones).
CLIPS.Dog = function(d)
	return { Run = CLIPS.Cat(d).Run }
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
	}
end

-- Aves: planean con las alas quietas, un poco levantadas.
CLIPS.Bird = function()
	return {
		Glide = {
			length = 1,
			loop = true,
			keys = { { t = 0, amp = { WingL = 0, WingR = 0 }, WingL = { 0, 0, -6 }, WingR = { 0, 0, 6 } } },
		},
	}
end

function PetModels.build(petId: string): Model?
	local pet = Pets[petId]
	local builder = voxelBuilders[petId] or builders[petId]
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
