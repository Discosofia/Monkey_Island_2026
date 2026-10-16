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
}
type Animated = {
	joints: { Joint },
	statics: { BasePart },
	rest: { CFrame }, -- de cada pieza fija, respecto al pivote
	clips: { [string]: Clip },
	scale: number,
	bodyMoved: boolean,
}

local WHITE = Color3.fromRGB(245, 245, 238)
local BLACK = Color3.fromRGB(22, 22, 26)
local CREAM = Color3.fromRGB(235, 215, 175)
-- Gira un cilindro (eje X) para ponerlo de pie.
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

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

-- Mancha de dos tonos pegada a un cuerpo: un óvalo y otro menor desplazado y girado encima. Así no
-- parecen lunares todos iguales.
local function blotch(
	rig: Rig,
	name: string,
	position: Vector3,
	normal: Vector3,
	size: Vector2,
	spin: number,
	color: Color3,
	inner: Color3
): { BasePart }
	local up = if math.abs(normal.Unit.Y) > 0.95 then Vector3.zAxis else Vector3.yAxis
	local frame = CFrame.lookAt(position, position + normal, up) * CFrame.Angles(0, 0, spin)
	return {
		piece(rig, name, "Oval", Vector3.new(size.X, size.Y, 0.05), frame, color),
		piece(
			rig,
			name,
			"Oval",
			Vector3.new(size.X * 0.55, size.Y * 0.7, 0.05),
			frame * CFrame.new(size.X * 0.22, -size.Y * 0.1, -0.008),
			inner
		),
	}
end

-- Cuatro patas (delante izquierda/derecha, detrás izquierda/derecha) que andan en diagonal, cada
-- una con su pie (del color "paw", o del de la pata) y, si se pide, tres dedos o uñas ("toes").
local function legs(
	rig: Rig,
	color: Color3,
	front: number,
	back: number,
	spread: number,
	y: number,
	size: Vector3,
	paw: Color3?,
	toes: Color3?
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
		if toes then
			local pawSize = foot.Size / rig.scale
			for k = -1, 1 do
				local toe = piece(
					rig,
					"Toe",
					"Ball",
					Vector3.one * pawSize.X * 0.28,
					CFrame.new(
						position
							+ Vector3.new(
								k * pawSize.X * 0.3,
								-size.Y * 0.42,
								-size.Z * 0.2 - pawSize.Z * 0.4 + math.abs(k) * 0.03
							)
					),
					toes
				)
				joint(rig, toe, hinge, Vector3.xAxis, 0.55, 9, phases[i], true)
			end
		end
	end
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

local BIRD_HEAD = Vector3.new(0, 0.68, -0.42)

-- Pluma suelta: óvalo plano que sale de "root" en la dirección "direction" (horizontal o casi).
-- Opcional: punta de otro color ("tip") en el último tercio y el cañón ("shaft"), una raya fina a lo
-- largo. Devuelve sus piezas para articularlas.
local function feather(
	rig: Rig,
	name: string,
	root: Vector3,
	direction: Vector3,
	length: number,
	width: number,
	color: Color3,
	tip: Color3?,
	shaft: Color3?
): { BasePart }
	local unit = direction.Unit
	local center = root + unit * length / 2
	local frame = CFrame.lookAt(center, center + unit)
	local parts = { piece(rig, name, "Oval", Vector3.new(width, 0.05, length), frame, color, Enum.Material.Fabric) }
	if tip then
		table.insert(
			parts,
			piece(
				rig,
				name .. "Tip",
				"Oval",
				Vector3.new(width * 0.85, 0.055, length * 0.4),
				frame * CFrame.new(0, 0, -length * 0.3),
				tip,
				Enum.Material.Fabric
			)
		)
	end
	if shaft then
		-- Un poco más gruesa que la pluma: asoma por arriba y por abajo, que se ve al batir.
		table.insert(
			parts,
			piece(
				rig,
				name .. "Shaft",
				"Oval",
				Vector3.new(math.min(0.03, width * 0.12), 0.064, length * 0.9),
				frame,
				shaft
			)
		)
	end
	return parts
end

type WingStyle = {
	span: number, -- largo del ala abierta, desde la bisagra
	chord: number, -- fondo de las cobertoras
	coverts: Color3, -- plumas pequeñas del borde de delante
	middle: Color3, -- cobertoras mayores, que tapan el arranque de las remeras
	middleTip: Color3?, -- punta de las cobertoras mayores
	flight: { Color3 }, -- remeras, de dentro (junto al cuerpo) a fuera
	tip: Color3?, -- punta de las remeras
	amplitude: number,
	speed: number,
}

-- Ala abierta de plumas sueltas, por capas como un ala de verdad: el brazo (borde de delante liso),
-- una fila de cobertoras pequeñas como escamas, otra de cobertoras mayores, la álula en la muñeca y
-- un abanico de remeras con su cañón, que van de apuntar atrás (las de dentro) a apuntar hacia
-- fuera (las de la punta). Todo bate con la misma bisagra, como una sola pieza.
local function featheredWing(rig: Rig, side: number, hinge: Vector3, style: WingStyle)
	local span, chord = style.span, style.chord
	local fabric = Enum.Material.Fabric
	local parts: { BasePart } = {
		piece(
			rig,
			"WingArm",
			"Oval",
			Vector3.new(span * 0.8, 0.13, chord * 0.55),
			CFrame.new(hinge + Vector3.new(side * span * 0.36, 0.03, -chord * 0.08)),
			style.coverts,
			fabric
		),
	}
	local function add(list: { BasePart })
		for _, part in list do
			table.insert(parts, part)
		end
	end
	-- Cobertoras pequeñas: escamas de dos tonos en fila sobre el brazo.
	local lesser = 5
	for k = 1, lesser do
		table.insert(
			parts,
			piece(
				rig,
				"LesserCovert",
				"Oval",
				Vector3.new(span * 0.17, 0.07, chord * 0.36),
				CFrame.new(hinge + Vector3.new(side * span * (0.06 + 0.14 * (k - 1)), 0.075, chord * 0.08)),
				if k % 2 == 0 then style.coverts else style.coverts:Lerp(WHITE, 0.1),
				fabric
			)
		)
	end
	-- Cobertoras mayores: plumas cortas que tapan el arranque de las remeras.
	local greater = 6
	for k = 1, greater do
		local t = (k - 1) / (greater - 1)
		local angle = math.rad(84 - 62 * t)
		local root = hinge + Vector3.new(side * span * (0.08 + 0.55 * t), 0.005 - 0.004 * k, chord * 0.02)
		local direction = Vector3.new(side * math.cos(angle), -0.03, math.sin(angle))
		add(feather(rig, "GreaterCovert", root, direction, chord * 0.8, span * 0.2, style.middle, style.middleTip))
	end
	-- Álula: plumita en la muñeca que apunta hacia fuera y adelante.
	add(
		feather(
			rig,
			"Alula",
			hinge + Vector3.new(side * span * 0.66, 0.06, -chord * 0.2),
			Vector3.new(side, 0.02, -0.12),
			span * 0.18,
			span * 0.08,
			style.coverts
		)
	)
	-- Remeras anchas y muy solapadas: si se separan, el ala parece una mano con dedos. Solo las de
	-- fuera llevan la punta de otro color: las de dentro quedan tapadas.
	local count = #style.flight
	for i, featherColor in style.flight do
		local t = (i - 1) / (count - 1)
		local angle = math.rad(82 - 70 * t)
		local root = hinge + Vector3.new(side * span * (0.12 + 0.62 * t), -0.035 - 0.008 * i, chord * 0.1)
		local direction = Vector3.new(side * math.cos(angle), -0.04, math.sin(angle))
		local length = span * (0.55 + 0.2 * t)
		local tip = if t >= 0.5 then style.tip else nil
		local shaft = featherColor:Lerp(WHITE, 0.4)
		add(feather(rig, "Flight", root, direction, length, span * 0.26, featherColor, tip, shaft))
	end
	for _, part in parts do
		joint(rig, part, CFrame.new(hinge), Vector3.zAxis, style.amplitude * side, style.speed, 0, false).bone = if side
				< 0
			then "WingL"
			else "WingR"
	end
end

-- Cola en abanico: "count" plumas desde "base" hacia atrás y algo hacia abajo ("droop", en
-- radianes), abiertas "spread" radianes en total. La del centro es la más larga.
local function tailFan(
	rig: Rig,
	base: Vector3,
	count: number,
	length: number,
	width: number,
	spread: number,
	droop: number,
	color: (index: number) -> Color3,
	tip: Color3?
)
	for i = 1, count do
		local t = if count > 1 then (i - 1) / (count - 1) - 0.5 else 0
		local angle = t * spread
		local direction = Vector3.new(math.sin(angle), -math.sin(droop), math.cos(angle))
		local root = base + Vector3.new(t * width * 0.6, 0.01 * math.abs(t), 0)
		feather(rig, "TailFeather", root, direction, length * (1 - math.abs(t) * 0.35), width, color(i), tip)
	end
end

-- Cuerpo y cabeza de ave con plumaje de tela, y patas recogidas de dos dedos delante y dos detrás.
local function bird(rig: Rig, color: Color3, feet: Color3)
	local fabric = Enum.Material.Fabric
	piece(rig, "Body", "Oval", Vector3.new(0.85, 1.05, 1.25), CFrame.Angles(0.35, 0, 0), color, fabric)
	-- Plumas del lomo y de los flancos, un tono más oscuro, solapadas como escamas.
	local shade = color:Lerp(BLACK, 0.18)
	piece(
		rig,
		"Mantle",
		"Oval",
		Vector3.new(0.7, 0.5, 0.7),
		CFrame.new(0, 0.28, 0.22) * CFrame.Angles(0.5, 0, 0),
		shade,
		fabric
	)
	for _, side in { -1, 1 } do
		piece(
			rig,
			"Flank",
			"Oval",
			Vector3.new(0.3, 0.6, 0.75),
			CFrame.new(side * 0.32, -0.12, 0.12) * CFrame.Angles(0.35, 0, side * 0.15),
			shade,
			fabric
		)
	end
	piece(rig, "Head", "Ball", Vector3.one * 0.72, CFrame.new(BIRD_HEAD), color, fabric)
	for _, side in { -1, 1 } do
		local ankle = Vector3.new(side * 0.18, -0.5, -0.02)
		piece(rig, "Leg", "Cylinder", Vector3.new(0.16, 0.09, 0.09), CFrame.new(ankle) * UPRIGHT, feet)
		for _, toe in { { side * -0.05, -0.18 }, { side * 0.06, -0.17 }, { side * -0.03, 0.14 }, { side * 0.05, 0.13 } } do
			local tipPoint = ankle + Vector3.new(toe[1], -0.08, toe[2])
			piece(
				rig,
				"Toe",
				"Oval",
				Vector3.new(0.06, 0.06, 0.2),
				CFrame.lookAt((ankle + tipPoint) / 2, tipPoint),
				feet
			)
			piece(rig, "Claw", "Ball", Vector3.one * 0.045, CFrame.new(tipPoint), BLACK)
		end
	end
end

-- Al final de cada ave: la cabeza cabecea y la cola sube y baja en vuelo. "neck" y "rump" son las
-- bisagras; la cabeza es lo que queda por encima de "headAbove" y por delante del cuello.
local function birdMotion(rig: Rig, neck: Vector3, headAbove: number, rump: Vector3)
	swingRegion(rig, neck, Vector3.xAxis, 0.1, 3, 0, false, function(position)
		return position.Y > headAbove and position.Z < neck.Z
	end)
	swingRegion(rig, rump, Vector3.xAxis, 0.15, 6, 1, false, function(position)
		return position.Z > rump.Z and position.Y < -0.1
	end)
end

-- Ojo de ave pegado a la cabeza (centro "head", radio "radius") en la dirección "direction": anillo
-- de piel, ojo del color del iris, pupila, dos brillos y un párpado de arriba que le da expresión.
local function birdEye(
	rig: Rig,
	head: Vector3,
	radius: number,
	direction: Vector3,
	size: number,
	iris: Color3,
	ring: Color3,
	lid: Color3
)
	local normal = direction.Unit
	local center = head + normal * radius
	local frame = CFrame.lookAt(center, center + normal)
	piece(rig, "EyeRing", "Oval", Vector3.new(size * 1.55, size * 1.45, 0.07), frame, ring)
	-- Medido desde el centro del ojo ("eye", que asoma del anillo): la pupila y los brillos tienen que
	-- quedar por fuera de la bola del ojo, o se entierran y el ojo sale sin pupila.
	local eye = frame * CFrame.new(0, 0, -0.02)
	piece(rig, "Eye", "Ball", Vector3.one * size, eye, iris)
	piece(
		rig,
		"Pupil",
		"Oval",
		Vector3.new(size * 0.5, size * 0.5, size * 0.2),
		eye * CFrame.new(0, 0, -size * 0.46),
		BLACK
	)
	piece(
		rig,
		"Glint",
		"Ball",
		Vector3.one * size * 0.18,
		eye * CFrame.new(-size * 0.14, size * 0.15, -size * 0.5),
		WHITE,
		Enum.Material.Neon
	)
	piece(
		rig,
		"Glint",
		"Ball",
		Vector3.one * size * 0.09,
		eye * CFrame.new(size * 0.13, -size * 0.1, -size * 0.5),
		WHITE,
		Enum.Material.Neon
	)
	piece(
		rig,
		"Eyelid",
		"Oval",
		Vector3.new(size * 1.15, size * 0.45, size * 0.8),
		eye * CFrame.new(0, size * 0.38, -size * 0.18) * CFrame.Angles(-0.25, 0, 0),
		lid
	)
end

local builders: { [string]: (rig: Rig, color: Color3) -> Motion } = {
	-- Tucán pico iris: negro, babero amarillo con filo rojo y un pico enorme de colores (verde en la
	-- base, naranja, azul por debajo y punta roja curvada) con el borde dentado.
	Tucan = function(rig, color)
		local fabric = Enum.Material.Fabric
		local lime = Color3.fromRGB(130, 195, 60)
		local orange = Color3.fromRGB(255, 150, 30)
		local red = Color3.fromRGB(215, 40, 30)
		local sky = Color3.fromRGB(80, 150, 235)
		local gloss = Color3.fromRGB(45, 48, 75)
		bird(rig, color, Color3.fromRGB(90, 110, 170))
		piece(
			rig,
			"Bib",
			"Oval",
			Vector3.new(0.64, 0.6, 0.36),
			CFrame.new(0, 0.32, -0.55),
			Color3.fromRGB(255, 220, 80),
			fabric
		)
		piece(
			rig,
			"BibEdge",
			"Oval",
			Vector3.new(0.56, 0.16, 0.3),
			CFrame.new(0, 0.03, -0.53) * CFrame.Angles(0.3, 0, 0),
			red,
			fabric
		)
		-- Cara: piel azul alrededor del ojo con el borde verde, mejillas amarillas que suben del babero
		-- hasta debajo del ojo, y ojo con anillo claro y párpado azul.
		local skin = Color3.fromRGB(70, 160, 230)
		for _, side in { -1, 1 } do
			-- Piel azul alrededor del ojo, alargada hacia atrás (dos óvalos solapados, no una diana). Los
			-- parches son óvalos hondos hundidos en la cabeza: uno plano se despega por los bordes.
			local look = Vector3.new(side * 0.72, 0.3, -0.62).Unit
			local back = Vector3.new(side * 0.8, 0.28, -0.35).Unit
			patch(rig, "EyeSkin", Vector3.new(0.36, 0.3, 0.2), BIRD_HEAD + look * 0.29, look, skin)
			patch(rig, "EyeSkin", Vector3.new(0.26, 0.2, 0.2), BIRD_HEAD + back * 0.28, back, skin:Lerp(lime, 0.25))
			local cheek = Vector3.new(side * 0.8, -0.42, -0.42).Unit
			patch(
				rig,
				"Cheek",
				Vector3.new(0.32, 0.26, 0.2),
				BIRD_HEAD + cheek * 0.28,
				cheek,
				Color3.fromRGB(255, 220, 80)
			)
			birdEye(
				rig,
				BIRD_HEAD,
				0.385,
				look,
				0.17,
				Color3.fromRGB(90, 140, 60),
				skin:Lerp(WHITE, 0.35),
				skin:Lerp(BLACK, 0.3)
			)
		end

		-- Pico: mandíbula de arriba (base verde, cuerpo naranja, cresta amarilla), la de abajo azul,
		-- punta roja curvada hacia abajo y la comisura oscura entre las dos.
		local upper = CFrame.new(0, 0.7, -1.33) * CFrame.Angles(-0.12, 0, 0)
		piece(rig, "BeakBase", "Oval", Vector3.new(0.42, 0.48, 0.34), CFrame.new(0, 0.64, -0.84), lime)
		piece(rig, "Beak", "Oval", Vector3.new(0.36, 0.32, 1.25), upper, orange)
		piece(
			rig,
			"BeakRidge",
			"Oval",
			Vector3.new(0.13, 0.08, 1.15),
			upper * CFrame.new(0, 0.14, 0.02),
			Color3.fromRGB(235, 220, 60)
		)
		piece(rig, "BeakStripe", "Oval", Vector3.new(0.37, 0.18, 0.32), upper * CFrame.new(0, 0, 0.42), lime)
		local lower = CFrame.new(0, 0.52, -1.24) * CFrame.Angles(-0.04, 0, 0)
		piece(rig, "LowerBeak", "Oval", Vector3.new(0.3, 0.2, 1.05), lower, sky)
		piece(rig, "LowerBase", "Oval", Vector3.new(0.31, 0.22, 0.35), CFrame.new(0, 0.54, -0.86), lime)
		piece(
			rig,
			"Gape",
			"Oval",
			Vector3.new(0.37, 0.025, 1.0),
			CFrame.new(0, 0.6, -1.28) * CFrame.Angles(-0.1, 0, 0),
			BLACK
		)
		piece(
			rig,
			"BeakTip",
			"Oval",
			Vector3.new(0.22, 0.27, 0.46),
			CFrame.new(0, 0.55, -1.9) * CFrame.Angles(-0.45, 0, 0),
			red
		)
		-- Dientes del borde del pico, a los dos lados.
		local teeth = 4
		for _, side in { -1, 1 } do
			for k = 1, teeth do
				-- Muescas finas justo bajo la comisura, que baja hacia la punta.
				local z = -0.98 - k * 0.17
				piece(
					rig,
					"BeakTooth",
					"Oval",
					Vector3.new(0.02, 0.055, 0.035),
					CFrame.new(side * 0.168, 0.6 + (z + 1.28) * 0.1, z),
					Color3.fromRGB(60, 35, 20)
				)
			end
			piece(rig, "Nostril", "Ball", Vector3.one * 0.05, CFrame.new(side * 0.09, 0.86, -0.82), BLACK)
		end

		for _, side in { -1, 1 } do
			featheredWing(rig, side, Vector3.new(side * 0.35, 0.22, 0.08), {
				span = 1.2,
				chord = 0.62,
				coverts = color,
				middle = color:Lerp(gloss, 0.5),
				flight = { color, color, color, gloss, color, gloss },
				tip = gloss,
				amplitude = 0.7,
				speed = 14,
			})
		end
		-- Rabadilla blanca, plumas rojas bajo la cola y cola negra en abanico.
		piece(rig, "Rump", "Oval", Vector3.new(0.42, 0.2, 0.32), CFrame.new(0, -0.14, 0.6), WHITE, fabric)
		piece(rig, "UnderTail", "Oval", Vector3.new(0.36, 0.22, 0.32), CFrame.new(0, -0.45, 0.45), red, fabric)
		tailFan(rig, Vector3.new(0, -0.3, 0.62), 5, 0.85, 0.2, 0.7, 0.45, function()
			return color
		end, gloss)
		birdMotion(rig, Vector3.new(0, 0.45, -0.25), 0.4, Vector3.new(0, -0.15, 0.35))
		rig.family = "Bird"
		return "Fly"
	end,

	-- Tortuga: caparazón alto de placas con anillos de crecimiento, borde de placas, peto amarillo,
	-- musgo y una florecita encima; cabeza con pico, párpados y rayas amarillas, y patas con uñas.
	Tortuga = function(rig, color)
		local skin = Color3.fromRGB(150, 170, 100)
		local skinDark = skin:Lerp(BLACK, 0.3)
		local stripe = Color3.fromRGB(235, 210, 90)
		local plate = color:Lerp(Color3.fromRGB(200, 180, 90), 0.35)
		local ring = color:Lerp(BLACK, 0.3)
		local seam = color:Lerp(BLACK, 0.5)
		local shellFrame = CFrame.new(0, 0.15, 0)
		local shellSemi = Vector3.new(0.85, 0.55, 1.0)
		piece(rig, "Shell", "Oval", shellSemi * 2, shellFrame, seam)
		piece(rig, "Rim", "Oval", Vector3.new(1.95, 0.3, 2.25), CFrame.new(0, -0.15, 0), ring)
		piece(
			rig,
			"Plastron",
			"Oval",
			Vector3.new(1.55, 0.28, 1.85),
			CFrame.new(0, -0.27, 0),
			Color3.fromRGB(215, 190, 110)
		)

		-- Placa del caparazón: plancha grande y, encima, el anillo de crecimiento y el centro, de tonos
		-- cercanos. Con material de madera, la veta parece las líneas de crecimiento. Entre placa y
		-- placa asoma el caparazón oscuro, que hace de junta.
		local function scute(direction: Vector3, size: Vector2)
			local position, normal = surfacePoint(shellFrame, shellSemi, direction)
			local up = if math.abs(normal.Y) > 0.7 then Vector3.zAxis else Vector3.yAxis
			local frame = CFrame.lookAt(position, position + normal, up)
			local wood = Enum.Material.Wood
			piece(rig, "Scute", "Oval", Vector3.new(size.X, size.Y, 0.14), frame, plate:Lerp(BLACK, 0.1), wood)
			piece(
				rig,
				"ScuteRing",
				"Oval",
				Vector3.new(size.X * 0.75, size.Y * 0.75, 0.14),
				frame * CFrame.new(0, 0, -0.012),
				plate,
				wood
			)
			piece(
				rig,
				"ScuteCenter",
				"Oval",
				Vector3.new(size.X * 0.42, size.Y * 0.42, 0.14),
				frame * CFrame.new(0, 0, -0.024),
				plate:Lerp(WHITE, 0.12),
				wood
			)
		end
		-- Fila del lomo (de delante atrás) y una fila grande en cada costado.
		for _, angle in { -58, -29, 0, 29, 58 } do
			local a = math.rad(angle)
			scute(Vector3.new(0, math.cos(a), math.sin(a) * 1.4), Vector2.new(0.62, 0.5))
		end
		for _, side in { -1, 1 } do
			for _, z in { -0.75, -0.25, 0.25, 0.75 } do
				scute(Vector3.new(side, 0.12, z * 1.3), Vector2.new(0.6, 0.72))
			end
		end
		-- Placas del borde del caparazón, alrededor de todo el contorno, de dos tonos alternos.
		local marginals = 16
		for i = 0, marginals - 1 do
			local angle = (i + 0.5) * 2 * math.pi / marginals
			local position = Vector3.new(math.cos(angle) * 0.93, -0.1, math.sin(angle) * 1.08)
			patch(
				rig,
				"EdgePlate",
				Vector3.new(0.34, 0.2, 0.12),
				position,
				position * Vector3.new(1, 0, 1),
				if i % 2 == 0 then plate:Lerp(BLACK, 0.12) else plate:Lerp(BLACK, 0.25)
			)
		end
		-- Musgo y una florecita sobre el caparazón.
		local moss = Color3.fromRGB(85, 135, 55)
		for _, spot in
			{
				{ Vector3.new(0.35, 1, 0.45), Vector2.new(0.42, 0.3) },
				{ Vector3.new(-0.45, 1, -0.2), Vector2.new(0.3, 0.24) },
			}
		do
			local position, normal = surfacePoint(shellFrame, shellSemi, spot[1])
			piece(
				rig,
				"Moss",
				"Oval",
				Vector3.new(spot[2].X, 0.1, spot[2].Y),
				CFrame.lookAt(position + normal * 0.03, position + normal * 0.03 + Vector3.zAxis, normal),
				moss,
				Enum.Material.Grass
			)
		end
		local stemBase = surfacePoint(shellFrame, shellSemi, Vector3.new(0.35, 1, 0.45))
		local bloom = stemBase + Vector3.new(0, 0.24, 0)
		piece(
			rig,
			"Stem",
			"Cylinder",
			Vector3.new(0.24, 0.035, 0.035),
			CFrame.new(stemBase + Vector3.new(0, 0.12, 0)) * UPRIGHT,
			moss
		)
		for k = 0, 4 do
			local angle = k * 2 * math.pi / 5
			piece(
				rig,
				"Petal",
				"Oval",
				Vector3.new(0.09, 0.03, 0.14),
				CFrame.new(bloom) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -0.07) * CFrame.Angles(0.3, 0, 0),
				Color3.fromRGB(255, 120, 160)
			)
		end
		piece(rig, "Bloom", "Ball", Vector3.one * 0.07, CFrame.new(bloom + Vector3.new(0, 0.02, 0)), stripe)

		-- Cabeza con cuello arrugado, pico, ojos con párpado y rayas amarillas: todo gira junto,
		-- mirando a los lados.
		piece(rig, "Neck", "Oval", Vector3.new(0.4, 0.38, 0.62), CFrame.new(0, 0, -1.0), skin)
		for _, z in { -0.92, -1.06 } do
			piece(rig, "Wrinkle", "Oval", Vector3.new(0.42, 0.39, 0.04), CFrame.new(0, 0, z), skinDark)
		end
		piece(rig, "Head", "Oval", Vector3.new(0.56, 0.5, 0.7), CFrame.new(0, 0.07, -1.32), skin)
		piece(rig, "Beak", "Oval", Vector3.new(0.36, 0.26, 0.22), CFrame.new(0, -0.0, -1.6), Color3.fromRGB(90, 85, 50))
		piece(rig, "Mouth", "Oval", Vector3.new(0.38, 0.025, 0.24), CFrame.new(0, -0.04, -1.56), BLACK)
		for _, side in { -1, 1 } do
			piece(rig, "Nostril", "Ball", Vector3.one * 0.035, CFrame.new(side * 0.05, 0.1, -1.66), BLACK)
			local eye = Vector3.new(side * 0.2, 0.15, -1.5)
			piece(rig, "Eye", "Ball", Vector3.one * 0.15, CFrame.new(eye), BLACK)
			piece(
				rig,
				"Glint",
				"Ball",
				Vector3.one * 0.05,
				CFrame.new(eye + Vector3.new(side * 0.01, 0.035, -0.06)),
				WHITE,
				Enum.Material.Neon
			)
			piece(
				rig,
				"Eyelid",
				"Oval",
				Vector3.new(0.18, 0.08, 0.17),
				CFrame.new(eye + Vector3.new(0, 0.06, 0.005)) * CFrame.Angles(0, 0, -side * 0.15),
				skinDark
			)
			-- Rayas amarillas en la mejilla, detrás del ojo, pegadas a la cabeza.
			for k = 0, 1 do
				local position, normal = surfacePoint(
					CFrame.new(0, 0.07, -1.32),
					Vector3.new(0.28, 0.25, 0.35),
					Vector3.new(side, 0.05 - k * 0.4, 0.25)
				)
				piece(
					rig,
					"Stripe",
					"Oval",
					Vector3.new(0.34, 0.045, 0.03),
					CFrame.lookAt(position, position + normal) * CFrame.Angles(0, 0, side * 0.12),
					stripe
				)
			end
		end
		-- Escamas oscuras en lo alto de la cabeza.
		for _, position in { Vector3.new(0, 0.32, -1.3), Vector3.new(0.1, 0.3, -1.15), Vector3.new(-0.1, 0.3, -1.15) } do
			patch(rig, "HeadScale", Vector3.new(0.12, 0.1, 0.04), position, Vector3.new(position.X, 1, 0), skinDark)
		end
		legs(rig, skin, -0.75, 0.75, 0.72, -0.35, Vector3.new(0.45, 0.45, 0.55), skinDark, Color3.fromRGB(120, 110, 70))
		piece(
			rig,
			"TailTip",
			"Wedge",
			Vector3.new(0.2, 0.2, 0.35),
			CFrame.new(0, -0.15, 1.2) * CFrame.Angles(0, math.pi, 0),
			skin
		)
		-- Las placas del borde de delante quedan por debajo (Y = -0,1) y no giran con la cabeza.
		swingRegion(rig, Vector3.new(0, 0, -0.85), Vector3.yAxis, 0.3, 1.5, 0, false, function(position)
			return position.Z < -0.8 and position.Y > -0.08
		end)
		return "Walk"
	end,

	-- Rana dardo azul: piel brillante como mojada con manchas negras, ojos negros saltones, patas de
	-- azul más oscuro y dedos largos con ventosas; va a saltos.
	Rana = function(rig, color)
		local navy = Color3.fromRGB(30, 60, 160)
		local pad = color:Lerp(WHITE, 0.3)
		-- Piel brillante, como mojada.
		local function glossy(part: BasePart): BasePart
			part.Reflectance = 0.12
			return part
		end
		local bodyFrame = CFrame.Angles(0.25, 0, 0)
		local bodySemi = Vector3.new(0.5, 0.36, 0.58)
		glossy(piece(rig, "Body", "Oval", bodySemi * 2, bodyFrame, color))
		glossy(piece(rig, "Head", "Oval", Vector3.new(0.84, 0.48, 0.66), CFrame.new(0, 0.12, -0.4), color))
		piece(rig, "Throat", "Oval", Vector3.new(0.6, 0.24, 0.5), CFrame.new(0, -0.17, -0.38), navy)
		-- Boca: una raya fina que rodea la cabeza por delante y por los lados.
		piece(rig, "Mouth", "Oval", Vector3.new(0.8, 0.025, 0.6), CFrame.new(0, 0.03, -0.42), BLACK)
		-- Manchas negras de tamaños distintos por el lomo, la cabeza y los costados.
		for _, spot in
			{
				{ Vector3.new(0.3, 1, 0.25), 0.32, 0.5 },
				{ Vector3.new(-0.3, 1, 0.05), 0.26, 1.4 },
				{ Vector3.new(0.05, 0.8, 0.75), 0.34, 2.2 },
				{ Vector3.new(-0.4, 0.7, 0.6), 0.2, 0.2 },
				{ Vector3.new(0.1, 1, -0.05), 0.16, 1.0 },
				{ Vector3.new(0.9, 0.3, 0.1), 0.26, 0.8 },
				{ Vector3.new(-0.9, 0.35, 0.25), 0.24, 2.6 },
				{ Vector3.new(-0.85, 0.15, -0.35), 0.15, 0.4 },
				{ Vector3.new(0.85, 0.4, 0.65), 0.18, 1.9 },
				{ Vector3.new(0.4, 0.8, 0.85), 0.14, 0 },
			}
		do
			local position, normal = surfacePoint(bodyFrame, bodySemi, spot[1])
			blotch(
				rig,
				"Spot",
				position,
				normal,
				Vector2.new(spot[2], spot[2] * 0.75),
				spot[3],
				BLACK,
				Color3.fromRGB(35, 40, 60)
			)
		end
		for _, side in { -1, 1 } do
			-- Ojo negro y brillante sobre su bulto, con párpado azul por encima.
			piece(rig, "EyeBump", "Ball", Vector3.one * 0.36, CFrame.new(side * 0.27, 0.34, -0.42), color)
			local eye = piece(rig, "Eye", "Ball", Vector3.one * 0.3, CFrame.new(side * 0.31, 0.4, -0.47), BLACK)
			eye.Reflectance = 0.15
			piece(
				rig,
				"Glint",
				"Ball",
				Vector3.one * 0.07,
				CFrame.new(side * 0.32, 0.48, -0.59),
				WHITE,
				Enum.Material.Neon
			)
			piece(
				rig,
				"Glint",
				"Ball",
				Vector3.one * 0.035,
				CFrame.new(side * 0.36, 0.42, -0.61),
				WHITE,
				Enum.Material.Neon
			)
			piece(rig, "Nostril", "Ball", Vector3.one * 0.035, CFrame.new(side * 0.07, 0.22, -0.69), BLACK)

			-- Pata de atrás plegada (muslo hacia delante, espinilla hacia atrás) y pie de cuatro
			-- dedos largos con ventosa en la punta.
			local hipPoint = Vector3.new(side * 0.36, -0.12, 0.3)
			local knee = Vector3.new(side * 0.62, -0.22, -0.08)
			local ankle = Vector3.new(side * 0.6, -0.36, 0.48)
			local back: { BasePart } = {
				glossy(capsule(rig, "Thigh", hipPoint, knee, 0.32, navy, Enum.Material.SmoothPlastic)),
				glossy(capsule(rig, "Shin", knee, ankle, 0.22, navy, Enum.Material.SmoothPlastic)),
			}
			local heel = Vector3.new(side * 0.64, -0.42, 0.36)
			for k = 0, 3 do
				local angle = math.rad(-25 + k * 22)
				local tip = heel + Vector3.new(side * math.sin(angle) * 0.42, -0.02, -math.cos(angle) * 0.42 + 0.05)
				table.insert(back, capsule(rig, "Toe", heel, tip, 0.06, navy, Enum.Material.SmoothPlastic))
				table.insert(back, piece(rig, "ToePad", "Ball", Vector3.one * 0.08, CFrame.new(tip), pad))
			end
			-- Pata de delante y mano de cuatro dedos con ventosas.
			local shoulderPoint = Vector3.new(side * 0.3, -0.06, -0.42)
			local wrist = Vector3.new(side * 0.4, -0.42, -0.55)
			local front: { BasePart } =
				{ glossy(capsule(rig, "FrontLeg", shoulderPoint, wrist, 0.16, navy, Enum.Material.SmoothPlastic)) }
			for k = 0, 3 do
				local angle = math.rad(-40 + k * 30)
				local tip = wrist + Vector3.new(side * math.sin(angle) * 0.17, -0.04, -math.cos(angle) * 0.17)
				table.insert(front, capsule(rig, "Finger", wrist, tip, 0.05, navy, Enum.Material.SmoothPlastic))
				table.insert(front, piece(rig, "ToePad", "Ball", Vector3.one * 0.065, CFrame.new(tip), pad))
			end
			-- Patalea al compás de los saltos (PetFollowers: |sin(reloj * 6)|): en el aire estira las
			-- traseras hacia abajo y atrás y adelanta las delanteras; al caer vuelven a su sitio (con
			-- bias = amplitud no pasan al otro lado: subían por detrás como una aleta). Solo al andar.
			local hip = CFrame.new(side * 0.35, -0.2, -0.05)
			for _, part in back do
				joint(rig, part, hip, Vector3.xAxis, 0.22, 12, -math.pi / 2, true, 0.22)
			end
			local shoulder = CFrame.new(side * 0.35, -0.05, -0.42)
			for _, part in front do
				joint(rig, part, shoulder, Vector3.xAxis, 0.25, 12, -math.pi / 2, true, 0.25)
			end
		end
		return "Hop"
	end,

	-- Guacamaya roja: cara blanca con hileras de plumitas rojas, pico ganchudo claro con la mandíbula
	-- de abajo negra, alas rojas, amarillas y azules, y cola muy larga roja con las puntas azules.
	Guacamaya = function(rig, color)
		local fabric = Enum.Material.Fabric
		local blue = Color3.fromRGB(40, 90, 220)
		local deepBlue = Color3.fromRGB(30, 55, 160)
		local yellow = Color3.fromRGB(250, 200, 40)
		local green = Color3.fromRGB(60, 170, 80)
		local horn = Color3.fromRGB(235, 225, 210)
		bird(rig, color, Color3.fromRGB(70, 70, 75))
		for _, side in { -1, 1 } do
			-- Cara de piel blanca; las plumitas rojas van en hileras sobre su cara de delante.
			local normal = Vector3.new(side * 0.72, -0.08, -0.69).Unit
			local frame = CFrame.lookAt(BIRD_HEAD + normal * 0.34, BIRD_HEAD + normal)
			local half = Vector3.new(0.19, 0.17, 0.045)
			piece(rig, "Face", "Oval", half * 2, frame, WHITE)
			-- Tres hileras finas que se abren hacia atrás, como en las guacamayas de verdad.
			for row = -1, 1 do
				piece(
					rig,
					"FaceLine",
					"Oval",
					Vector3.new(0.24, 0.028, 0.02),
					frame
						* CFrame.new(side * 0.02, row * 0.065 - 0.03, -half.Z + 0.006)
						* CFrame.Angles(0, 0, side * row * 0.18),
					color:Lerp(BLACK, 0.2)
				)
			end
			-- Mancha negra en la base del pico, a cada lado.
			piece(rig, "BeakPatch", "Oval", Vector3.new(0.06, 0.14, 0.18), CFrame.new(side * 0.11, 0.58, -0.76), BLACK)
		end
		-- Ojo de iris claro (amarillento) sobre la piel blanca, con anillo gris y párpado blanco.
		for _, side in { -1, 1 } do
			local look = Vector3.new(side * 0.7, 0.28, -0.66)
			birdEye(
				rig,
				BIRD_HEAD,
				0.385,
				look,
				0.15,
				Color3.fromRGB(250, 225, 140),
				Color3.fromRGB(215, 215, 205),
				WHITE
			)
		end
		-- Plumas rojas de la frente que montan sobre la base del pico, la cera clara con los orificios
		-- de la nariz y la lengua oscura entre las dos mandíbulas.
		piece(
			rig,
			"Forehead",
			"Oval",
			Vector3.new(0.3, 0.16, 0.24),
			CFrame.new(0, 0.86, -0.66) * CFrame.Angles(0.35, 0, 0),
			color:Lerp(Color3.fromRGB(255, 120, 60), 0.15),
			fabric
		)
		piece(
			rig,
			"Cere",
			"Oval",
			Vector3.new(0.17, 0.07, 0.12),
			CFrame.new(0, 0.8, -0.71),
			Color3.fromRGB(225, 215, 205)
		)
		for _, side in { -1, 1 } do
			piece(rig, "Nostril", "Ball", Vector3.one * 0.035, CFrame.new(side * 0.04, 0.825, -0.73), BLACK)
		end
		piece(rig, "Tongue", "Ball", Vector3.one * 0.09, CFrame.new(0, 0.54, -0.86), Color3.fromRGB(45, 40, 45))

		-- Pico ganchudo: base clara, gancho que baja curvado con la punta oscura y mandíbula negra.
		piece(rig, "Beak", "Oval", Vector3.new(0.26, 0.3, 0.3), CFrame.new(0, 0.65, -0.78), horn)
		local hookFrom, hookTo = Vector3.new(0, 0.68, -0.88), Vector3.new(0, 0.42, -0.93)
		piece(
			rig,
			"BeakHook",
			"Oval",
			Vector3.new(0.17, 0.15, 0.36),
			CFrame.lookAt((hookFrom + hookTo) / 2, hookTo),
			horn
		)
		piece(rig, "BeakTip", "Ball", Vector3.one * 0.08, CFrame.new(0, 0.43, -0.92), Color3.fromRGB(60, 58, 60))
		piece(rig, "LowerBeak", "Oval", Vector3.new(0.22, 0.2, 0.24), CFrame.new(0, 0.5, -0.76), BLACK)

		for _, side in { -1, 1 } do
			featheredWing(rig, side, Vector3.new(side * 0.35, 0.22, 0.08), {
				span = 1.25,
				chord = 0.65,
				coverts = color,
				middle = yellow,
				middleTip = green,
				flight = { blue, blue, blue, blue, blue, blue },
				tip = deepBlue,
				amplitude = 0.7,
				speed = 12,
			})
		end
		piece(rig, "Rump", "Oval", Vector3.new(0.4, 0.2, 0.34), CFrame.new(0, -0.15, 0.58), color, fabric)
		tailFan(rig, Vector3.new(0, -0.3, 0.6), 5, 1.7, 0.17, 0.4, 0.4, function(index)
			return if index == 1 or index == 5 then blue else color
		end, blue)
		birdMotion(rig, Vector3.new(0, 0.45, -0.25), 0.4, Vector3.new(0, -0.15, 0.35))
		rig.family = "Bird"
		return "Fly"
	end,

	-- Perezoso de tres dedos: pelo largo y desgreñado con manchas de alga, cara clara con antifaz
	-- oscuro y sonrisa, brazos largos con tres garras curvas y un hatillo de troncos a la espalda.
	Perezoso = function(rig, color)
		local fabric = Enum.Material.Fabric
		local dark = Color3.fromRGB(60, 40, 30)
		local shag = color:Lerp(BLACK, 0.18)
		local pale = color:Lerp(WHITE, 0.3)
		local claw = Color3.fromRGB(215, 200, 165)
		local clawTip = Color3.fromRGB(110, 90, 70)
		piece(rig, "Body", "Oval", Vector3.new(1.3, 1.4, 1.1), CFrame.identity, color, fabric)
		piece(rig, "Belly", "Oval", Vector3.new(0.9, 1.0, 0.3), CFrame.new(0, -0.05, -0.45), pale, fabric)
		-- Mechones colgando por el cuerpo, alternando tonos: el pelo desgreñado del perezoso.
		for i, spot in
			{
				{ Vector3.new(0.62, 0.1, -0.05), -0.3 },
				{ Vector3.new(0.58, -0.3, 0.15), -0.2 },
				{ Vector3.new(-0.62, 0.05, 0.05), 0.3 },
				{ Vector3.new(-0.56, -0.35, -0.1), 0.2 },
				{ Vector3.new(0.35, -0.6, 0.25), -0.1 },
				{ Vector3.new(-0.3, -0.62, 0.3), 0.1 },
				{ Vector3.new(0.3, 0.4, 0.42), 0 },
				{ Vector3.new(-0.32, 0.3, 0.45), 0 },
				{ Vector3.new(0.4, -0.25, -0.38), -0.2 },
				{ Vector3.new(-0.4, -0.3, -0.36), 0.2 },
			}
		do
			piece(
				rig,
				"Shag",
				"Oval",
				Vector3.new(0.26, 0.5, 0.2),
				CFrame.new(spot[1]) * CFrame.Angles(0, 0, spot[2]),
				if i % 2 == 0 then shag else color:Lerp(WHITE, 0.08),
				fabric
			)
		end
		-- Manchas de alga verdosa en el pelo, como los perezosos de verdad.
		local algae = color:Lerp(Color3.fromRGB(110, 150, 80), 0.55)
		for i, direction in
			{
				Vector3.new(0.8, 0.4, 0.3),
				Vector3.new(-0.7, 0.1, 0.5),
				Vector3.new(0.5, -0.5, 0.6),
				Vector3.new(-0.6, 0.55, -0.1),
			}
		do
			local position, normal = surfacePoint(CFrame.identity, Vector3.new(0.65, 0.7, 0.55), direction)
			blotch(
				rig,
				"Algae",
				position,
				normal,
				Vector2.new(0.42, 0.3),
				i * 1.1,
				algae,
				algae:Lerp(Color3.fromRGB(90, 140, 60), 0.4)
			)
		end

		-- Cabeza: gorro de pelo más oscuro, cara clara hundida en la cabeza (no es un plato pegado),
		-- antifaz que va de los ojos hacia atrás, nariz con orificios y sonrisa.
		local head = Vector3.new(0, 0.85, -0.25)
		piece(rig, "Head", "Ball", Vector3.one * 0.95, CFrame.new(head), color, fabric)
		piece(rig, "HairCap", "Ball", Vector3.one * 0.9, CFrame.new(head + Vector3.new(0, 0.1, 0.06)), shag, fabric)
		local faceFrame = CFrame.new(head + Vector3.new(0, -0.03, -0.29))
		local faceSemi = Vector3.new(0.37, 0.31, 0.25)
		piece(rig, "Face", "Oval", faceSemi * 2, faceFrame, CREAM, fabric)
		for _, side in { -1, 1 } do
			local position, normal = surfacePoint(faceFrame, faceSemi, Vector3.new(side * 0.55, 0.25, -0.8))
			local maskFrame = CFrame.lookAt(position, position + normal) * CFrame.Angles(0, 0, side * 0.3)
			piece(
				rig,
				"Mask",
				"Oval",
				Vector3.new(0.4, 0.15, 0.08),
				maskFrame * CFrame.new(side * 0.06, 0, 0),
				dark,
				fabric
			)
			piece(rig, "Eye", "Ball", Vector3.one * 0.11, maskFrame * CFrame.new(0, 0.01, -0.04), BLACK)
			piece(
				rig,
				"Glint",
				"Ball",
				Vector3.one * 0.035,
				maskFrame * CFrame.new(side * 0.015, 0.035, -0.09),
				WHITE,
				Enum.Material.Neon
			)
			piece(rig, "Nostril", "Ball", Vector3.one * 0.04, CFrame.new(side * 0.045, 0.765, -0.868), BLACK)
			-- Media sonrisa: dos tramos que suben hacia las comisuras.
			piece(
				rig,
				"Smile",
				"Oval",
				Vector3.new(0.15, 0.035, 0.04),
				CFrame.new(side * 0.065, 0.655, -0.765) * CFrame.Angles(0, -side * 0.35, side * 0.4),
				dark
			)
		end
		piece(rig, "Nose", "Oval", Vector3.new(0.2, 0.13, 0.1), CFrame.new(0, 0.77, -0.82), dark)
		-- Pelo revuelto en la coronilla.
		for _, position in
			{
				Vector3.new(0, 1.33, -0.2),
				Vector3.new(0.2, 1.28, -0.1),
				Vector3.new(-0.2, 1.28, -0.1),
				Vector3.new(0.1, 1.3, 0.08),
				Vector3.new(-0.12, 1.31, 0.06),
			}
		do
			piece(
				rig,
				"Tuft",
				"Oval",
				Vector3.new(0.24, 0.26, 0.24),
				CFrame.new(position) * CFrame.Angles(0.3, 0, position.X * 2),
				shag,
				fabric
			)
		end

		-- Brazos largos con un mechón en el antebrazo y mano de tres garras curvas (de dos tramos:
		-- bajan y se doblan hacia delante). Se balancean al andar.
		for _, side in { -1, 1 } do
			local shoulder = Vector3.new(side * 0.6, 0.42, -0.25)
			local elbow = Vector3.new(side * 0.82, -0.12, -0.38)
			local wrist = Vector3.new(side * 0.8, -0.55, -0.45)
			local arm: { BasePart } = {
				piece(rig, "Shoulder", "Ball", Vector3.one * 0.42, CFrame.new(shoulder), color, fabric),
				capsule(rig, "UpperArm", shoulder, elbow, 0.32, color),
				capsule(rig, "Forearm", elbow, wrist, 0.3, color),
				piece(
					rig,
					"ArmShag",
					"Oval",
					Vector3.new(0.18, 0.42, 0.18),
					CFrame.new(elbow + Vector3.new(side * 0.1, -0.15, 0.1)) * CFrame.Angles(0.3, 0, side * 0.2),
					shag,
					fabric
				),
				piece(
					rig,
					"Hand",
					"Oval",
					Vector3.new(0.3, 0.22, 0.3),
					CFrame.new(wrist + Vector3.new(0, -0.1, -0.02)),
					dark,
					fabric
				),
			}
			for k = -1, 1 do
				local base = wrist + Vector3.new(k * 0.085, -0.17, -0.06)
				local bend = base + Vector3.new(0, -0.22, -0.04)
				local tip = bend + Vector3.new(0, -0.03, -0.14)
				table.insert(arm, capsule(rig, "Claw", base, bend, 0.055, claw, Enum.Material.SmoothPlastic))
				table.insert(arm, capsule(rig, "ClawTip", bend, tip, 0.045, clawTip, Enum.Material.SmoothPlastic))
			end
			local armPhase = if side < 0 then 0 else math.pi
			for _, part in arm do
				joint(rig, part, CFrame.new(shoulder), Vector3.xAxis, 0.5, 4, armPhase, true)
			end

			local hip = Vector3.new(side * 0.35, -0.45, 0)
			local leg: { BasePart } = {
				piece(
					rig,
					"Leg",
					"Oval",
					Vector3.new(0.38, 0.55, 0.4),
					CFrame.new(side * 0.35, -0.72, 0),
					color,
					fabric
				),
				piece(
					rig,
					"Foot",
					"Oval",
					Vector3.new(0.3, 0.14, 0.38),
					CFrame.new(side * 0.36, -0.98, -0.08),
					dark,
					fabric
				),
			}
			for k = -1, 1 do
				local base = Vector3.new(side * 0.36 + k * 0.08, -0.99, -0.24)
				table.insert(
					leg,
					capsule(
						rig,
						"Claw",
						base,
						base + Vector3.new(0, -0.02, -0.16),
						0.05,
						claw,
						Enum.Material.SmoothPlastic
					)
				)
			end
			for _, part in leg do
				joint(rig, part, CFrame.new(hip), Vector3.xAxis, 0.4, 4, if side < 0 then math.pi else 0, true)
			end
		end

		-- Hatillo de tres troncos con vetas y anillos en las puntas, atado con cuerda y tirantes que
		-- pasan por los hombros, y un brote de hojas.
		local wood = Color3.fromRGB(120, 85, 50)
		local cut = Color3.fromRGB(205, 160, 105)
		for _, position in { Vector3.new(0, 0.05, 0.7), Vector3.new(0, 0.42, 0.7), Vector3.new(0, 0.24, 1.0) } do
			piece(rig, "Log", "Cylinder", Vector3.new(1.5, 0.36, 0.36), CFrame.new(position), wood, Enum.Material.Wood)
			for _, side in { -1, 1 } do
				local face = position + Vector3.new(side * 0.75, 0, 0)
				piece(rig, "LogEnd", "Cylinder", Vector3.new(0.02, 0.3, 0.3), CFrame.new(face), cut, Enum.Material.Wood)
				piece(
					rig,
					"LogRing",
					"Cylinder",
					Vector3.new(0.025, 0.16, 0.16),
					CFrame.new(face),
					cut:Lerp(wood, 0.5),
					Enum.Material.Wood
				)
			end
		end
		for _, x in { -0.42, 0.42 } do
			piece(rig, "Rope", "Oval", Vector3.new(0.1, 0.9, 0.78), CFrame.new(x, 0.24, 0.84), CREAM, fabric)
		end
		for _, side in { -1, 1 } do
			local from = Vector3.new(side * 0.42, 0.55, 0.62)
			local to = Vector3.new(side * 0.4, 0.1, -0.52)
			local over = Vector3.new(side * 0.42, 0.72, -0.05)
			piece(
				rig,
				"Strap",
				"Oval",
				Vector3.new(0.1, 0.06, (over - from).Magnitude + 0.1),
				CFrame.lookAt((from + over) / 2, over),
				CREAM,
				fabric
			)
			piece(
				rig,
				"Strap",
				"Oval",
				Vector3.new(0.1, 0.06, (to - over).Magnitude + 0.1),
				CFrame.lookAt((over + to) / 2, to),
				CREAM,
				fabric
			)
		end
		local leafColor = Color3.fromRGB(70, 150, 60)
		for _, side in { -1, 1 } do
			piece(
				rig,
				"Leaf",
				"Oval",
				Vector3.new(0.16, 0.03, 0.34),
				CFrame.new(0.5, 0.72, 0.75)
					* CFrame.Angles(0, side * 0.6, 0)
					* CFrame.new(0, 0, -0.12)
					* CFrame.Angles(0.5, 0, 0),
				leafColor
			)
		end
		-- Ladea la cabeza muy despacio, como buen perezoso.
		swingRegion(rig, Vector3.new(0, 0.6, -0.1), Vector3.zAxis, 0.15, 0.6, 0, false, function(position)
			return position.Y > 0.6 and position.Z < 0.1 and math.abs(position.X) < 0.5
		end)
		return "Walk"
	end,

	-- Jaguarundí: felino esbelto, liso y oscuro.
	Jaguarundi = function(rig, color)
		cat(rig, color, { eyeColor = Color3.fromRGB(200, 170, 40), earSize = 0.24, roundEars = true, slim = true })
		return "Walk"
	end,

	-- Colibrí: diminuto y tornasolado (verde metálico), gorguera de escamas magenta que brillan,
	-- mota blanca tras el ojo, pico largo un poco curvo, alas estrechas que zumban y cola en abanico con puntas blancas.
	Colibri = function(rig, color)
		local metal = Enum.Material.Metal
		local magenta = Color3.fromRGB(220, 40, 120)
		local wingColor = Color3.fromRGB(70, 80, 75)
		local function sheen(part: BasePart): BasePart
			part.Reflectance = 0.15
			return part
		end
		sheen(piece(rig, "Body", "Oval", Vector3.new(0.55, 0.6, 1.0), CFrame.Angles(0.6, 0, 0), color, metal))
		piece(
			rig,
			"Belly",
			"Oval",
			Vector3.new(0.4, 0.45, 0.6),
			CFrame.new(0, -0.1, -0.12) * CFrame.Angles(0.6, 0, 0),
			Color3.fromRGB(215, 220, 210),
			Enum.Material.Fabric
		)
		sheen(piece(rig, "Head", "Ball", Vector3.one * 0.5, CFrame.new(0, 0.45, -0.35), color, metal))
		-- Coronilla más clara: una bola algo menor que la cabeza, subida, que solo asoma por arriba (un
		-- óvalo encima parecía una boina).
		sheen(
			piece(
				rig,
				"Crown",
				"Ball",
				Vector3.one * 0.46,
				CFrame.new(0, 0.52, -0.33),
				color:Lerp(Color3.fromRGB(120, 255, 220), 0.35),
				metal
			)
		)
		-- Gorguera: base magenta y escamas de dos tonos en filas, como las plumas que brillan.
		local throatFrame = CFrame.new(0, 0.2, -0.4)
		local throatSemi = Vector3.new(0.2, 0.17, 0.15)
		sheen(piece(rig, "Gorget", "Oval", throatSemi * 2, throatFrame, magenta, metal))
		for row = 0, 2 do
			for k = -1, 1 do
				local position, normal =
					surfacePoint(throatFrame, throatSemi, Vector3.new(k * 0.55 + (row % 2) * 0.2, 0.55 - row * 0.5, -1))
				local frame = CFrame.lookAt(position, position + normal)
				sheen(
					piece(
						rig,
						"GorgetScale",
						"Oval",
						Vector3.new(0.11, 0.08, 0.03),
						frame,
						magenta:Lerp(WHITE, 0.25),
						metal
					)
				)
				piece(
					rig,
					"GorgetScale",
					"Oval",
					Vector3.new(0.07, 0.04, 0.03),
					frame * CFrame.new(0, -0.012, -0.005),
					magenta:Lerp(BLACK, 0.2),
					metal
				)
			end
		end
		-- Escamas tornasoladas en la coronilla, de dos tonos alternos.
		local crownFrame = CFrame.new(0, 0.52, -0.33)
		for i, direction in
			{
				Vector3.new(0, 0.55, -1),
				Vector3.new(0.45, 0.75, -0.7),
				Vector3.new(-0.45, 0.75, -0.7),
				Vector3.new(0, 1, -0.35),
				Vector3.new(0.3, 1, 0.05),
				Vector3.new(-0.3, 1, 0.05),
			}
		do
			local position, normal = surfacePoint(crownFrame, Vector3.one * 0.23, direction)
			sheen(
				piece(
					rig,
					"CrownScale",
					"Oval",
					Vector3.new(0.11, 0.08, 0.05),
					CFrame.lookAt(position - normal * 0.018, position),
					color:Lerp(Color3.fromRGB(150, 255, 230), if i % 2 == 0 then 0.55 else 0.25),
					metal
				)
			)
		end
		-- Cara: antifaz oscuro alrededor del ojo y la mota blanca detrás.
		local head = Vector3.new(0, 0.45, -0.35)
		for _, side in { -1, 1 } do
			local look = Vector3.new(side * 0.62, 0.3, -0.72).Unit
			patch(rig, "Mask", Vector3.new(0.2, 0.15, 0.05), head + look * 0.245, look, color:Lerp(BLACK, 0.6))
			birdEye(rig, head, 0.255, look, 0.11, Color3.fromRGB(30, 22, 20), color:Lerp(BLACK, 0.7), color)
			local behind = Vector3.new(side * 0.85, 0.32, 0.12).Unit
			patch(rig, "EyeSpot", Vector3.new(0.09, 0.055, 0.04), head + behind * 0.25, behind, WHITE)
			piece(rig, "Foot", "Ball", Vector3.one * 0.08, CFrame.new(side * 0.08, -0.35, -0.1), BLACK)
		end
		-- Pico largo en dos tramos, el de la punta algo caído.
		local beakMid = Vector3.new(0, 0.44, -0.95)
		capsule(rig, "Beak", Vector3.new(0, 0.46, -0.55), beakMid, 0.07, BLACK, Enum.Material.SmoothPlastic)
		capsule(rig, "BeakTip", beakMid, Vector3.new(0, 0.38, -1.3), 0.055, BLACK, Enum.Material.SmoothPlastic)
		for _, side in { -1, 1 } do
			featheredWing(rig, side, Vector3.new(side * 0.15, 0.3, 0.05), {
				span = 0.95,
				chord = 0.34,
				coverts = color,
				middle = color:Lerp(wingColor, 0.5),
				flight = { wingColor, wingColor, wingColor, wingColor, wingColor },
				tip = wingColor:Lerp(BLACK, 0.3),
				amplitude = 0.9,
				speed = 45,
			})
		end
		-- Cola en abanico: la pluma del centro verde y las de los lados oscuras, con la punta blanca.
		tailFan(rig, Vector3.new(0, -0.3, 0.42), 5, 0.5, 0.13, 0.9, 0.6, function(index)
			return if index == 3 then color else color:Lerp(BLACK, 0.45)
		end, WHITE)
		birdMotion(rig, Vector3.new(0, 0.3, -0.2), 0.3, Vector3.new(0, -0.1, 0.3))
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

		-- Casco de caricatura; la cara no se ve: la tapa un visor de espejo. Todo lo del casco se mide
		-- desde "head" con onHead y se multiplica por "hk": cambiando hk crece o encoge entero.
		local hk = 0.78
		local head = Vector3.new(0, 0.86, -0.5)
		local function onHead(offset: Vector3): Vector3
			return head + offset * hk
		end
		piece(rig, "Helmet", "Ball", Vector3.one * 1.36 * hk, CFrame.new(head), shell)
		local facing = CFrame.Angles(0, math.pi / 2, 0)
		piece(
			rig,
			"VisorRim",
			"Cylinder",
			Vector3.new(0.14, 1.1, 1.1) * hk,
			CFrame.new(onHead(Vector3.new(0, 0, -0.5))) * facing,
			copper
		)
		-- Visor: cúpula que sobresale del aro, oscura y con reflejo de espejo, y un brillo blanco en
		-- diagonal arriba a un lado, como en los cascos de dibujos animados.
		local visorCenter = onHead(Vector3.new(0, 0, -0.56))
		local visorSize = Vector3.new(0.98, 0.94, 0.44) * hk
		local visor = piece(rig, "Visor", "Oval", visorSize, CFrame.new(visorCenter), Color3.fromRGB(25, 35, 55))
		visor.Reflectance = 0.6
		for _, shine in { { -0.22, 0.17, Vector3.new(0.09, 0.3, 0.04) }, { -0.05, 0.3, Vector3.new(0.07, 0.07, 0.04) } } do
			-- Punto de la superficie de la cúpula y su normal (elipsoide de semiejes visorSize / 2).
			local axes = visorSize / 2
			local x, y = shine[1] * hk, shine[2] * hk
			local z = -axes.Z * math.sqrt(1 - (x / axes.X) ^ 2 - (y / axes.Y) ^ 2)
			local normal = Vector3.new(x / axes.X ^ 2, y / axes.Y ^ 2, z / axes.Z ^ 2).Unit
			local position = visorCenter + Vector3.new(x, y, z) + normal * 0.01
			local glint = piece(
				rig,
				"VisorShine",
				"Oval",
				shine[3] * Vector3.new(hk, hk, 1),
				CFrame.lookAt(position, position + normal) * CFrame.Angles(0, 0, -0.6),
				WHITE
			)
			glint.Transparency = 0.15
		end
		-- Remaches del aro de la abertura.
		local rivets = 8
		for i = 1, rivets do
			local angle = (i - 0.5) * 2 * math.pi / rivets
			local position = onHead(Vector3.new(math.cos(angle) * 0.51, math.sin(angle) * 0.51, -0.575))
			piece(rig, "Rivet", "Ball", Vector3.one * 0.07 * hk, CFrame.new(position), metal)
		end

		-- Casco: cresta de delante atrás, cuello de cobre, discos en las sienes y manchas de óxido.
		piece(rig, "Crest", "Cylinder", Vector3.new(0.14, 1.42, 1.42) * hk, CFrame.new(head), shell:Lerp(metal, 0.35))
		piece(
			rig,
			"Collar",
			"Cylinder",
			Vector3.new(0.18, 1.0, 1.0) * hk,
			CFrame.new(onHead(Vector3.new(0, -0.6, 0.05))) * UPRIGHT,
			copper
		)
		for _, side in { -1, 1 } do
			local temple = onHead(Vector3.new(side * 0.66, -0.05, 0.08))
			piece(rig, "EarDisc", "Cylinder", Vector3.new(0.14, 0.44, 0.44) * hk, CFrame.new(temple), metal)
			piece(
				rig,
				"EarRing",
				"Cylinder",
				Vector3.new(0.16, 0.3, 0.3) * hk,
				CFrame.new(temple + Vector3.new(side * 0.02, 0, 0) * hk),
				copper
			)
			piece(
				rig,
				"EarKnob",
				"Ball",
				Vector3.one * 0.14 * hk,
				CFrame.new(temple + Vector3.new(side * 0.08, 0, 0) * hk),
				metal
			)
		end
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
			local center = onHead(normal * 0.675)
			local frame = CFrame.lookAt(center, center + normal) * CFrame.Angles(0, 0, i * 1.3)
			local k = spot[2] * hk
			piece(rig, "Rust", "Oval", Vector3.new(0.36 * k, 0.2 * k, 0.05), frame, rust)
			piece(
				rig,
				"Rust",
				"Oval",
				Vector3.new(0.2 * k, 0.15 * k, 0.05),
				frame * CFrame.new(0.14 * k, -0.06 * k, -0.006),
				rust:Lerp(shell, 0.4)
			)
		end
		-- Placa con su número en la frente, a un lado de la cresta.
		local badgeNormal = Vector3.new(0.4, 0.72, -0.56).Unit
		local badge = piece(
			rig,
			"Badge",
			"Block",
			Vector3.new(0.34 * hk, 0.15 * hk, 0.04),
			CFrame.lookAt(onHead(badgeNormal * 0.69), onHead(badgeNormal * 2)),
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

		-- El casco mira a un lado y a otro, con todo lo que lleva pegado (también los remaches de
		-- abajo; el cuello de cobre no, que es redondo y girarlo no se nota). La antena se registra
		-- después: se balancea por su cuenta colgada del casco, así que lo sigue en los clips.
		local helmet = swingRegion(rig, head, Vector3.yAxis, 0.3, 0.7, 0, false, function(position)
			return (position - head).Magnitude < 0.8 * hk and position.Y > head.Y - 0.55 * hk
		end, "Head")

		-- Antena: base, espiral de anillos que se estrecha y punta que brilla; se balancea un poco.
		local top = onHead(Vector3.new(0, 0.66, 0))
		local antenna: { BasePart } = {
			piece(
				rig,
				"AntennaBase",
				"Cylinder",
				Vector3.new(0.14, 0.34, 0.34) * hk,
				CFrame.new(top) * UPRIGHT,
				copper
			),
		}
		local rings = 5
		for i = 1, rings do
			local width = (0.3 - (i - 1) * 0.05) * hk
			local ringColor = if i % 2 == 1 then shell:Lerp(metal, 0.3) else metal
			table.insert(
				antenna,
				piece(
					rig,
					"AntennaRing",
					"Cylinder",
					Vector3.new(0.1 * hk, width, width),
					CFrame.new(top + Vector3.new(0, 0.04 + i * 0.08, 0) * hk) * UPRIGHT,
					ringColor
				)
			)
		end
		local tipPosition = top + Vector3.new(0, 0.58, 0) * hk
		local tip =
			piece(rig, "AntennaTip", "Ball", Vector3.one * 0.2 * hk, CFrame.new(tipPosition), color, Enum.Material.Neon)
		table.insert(antenna, tip)
		table.insert(
			antenna,
			piece(
				rig,
				"AntennaGlow",
				"Ball",
				Vector3.one * 0.32 * hk,
				CFrame.new(tipPosition),
				color,
				Enum.Material.Neon
			)
		)
		antenna[#antenna].Transparency = 0.6
		for _, part in antenna do
			joint(rig, part, CFrame.new(top), Vector3.zAxis, 0.08, 3, 0, false, nil, helmet[1])
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
			local from = onHead(Vector3.new(side * 0.62, -0.2, 0.22))
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

		-- Aura de energía: chispas azules que salen del cuerpo (la nube eléctrica de la foto). Salen
		-- de la superficie hacia fuera y deprisa: desde dentro del óvalo, lentas, se quedaban
		-- escondidas bajo el pelo y no se veían. Con LightEmission 1 de día salían casi blancas: con
		-- 0,4 y algo de Brightness conservan el azul. Un segundo foco en la mochila, como la foto.
		local body = rig.model:FindFirstChild("Body")
		local pack = rig.model:FindFirstChild("Pack")
		if body and pack then
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
				joint(rig, part, CFrame.new(shoulder), Vector3.xAxis, 0.35, 8, if side < 0 then 0 else math.pi, true).bone = if side
						< 0
					then "ArmL"
					else "ArmR"
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
				joint(rig, part, CFrame.new(hip), Vector3.xAxis, 0.35, 8, if side < 0 then math.pi else 0, true).bone = if side
						< 0
					then "LegL"
					else "LegR"
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
		rig.family = "X7"
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
		cat(rig, color, options)
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
	local lieDrop = d.bodyY - 0.44 - d.ground
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
	local sideDrop = d.bodyY - d.ground - 0.5
	local SIDE: Key = {
		Body = { 0, 0, 90, 0, -sideDrop, 0 },
		FL = { 25, 0, 0 },
		FR = { 35, 0, 0 },
		BL = { 20, 0, 0 },
		BR = { 30, 0, 0 },
		Head = { 0, 0, -30 },
		Tail = { 0, 14, 0 },
	}
	local bellyDrop = d.bodyY - d.ground - 0.72
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
			around = Vector3.new(0, -0.35, 0.45),
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
-- más barato que cambiar el CFrame de cada una.
function PetModels.animate(model: Model, time: number, moving: number, layers: { Layer }?, stride: number?)
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
	local count = #joints + (if moveStatics then #animated.statics else 0)
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
	if model:IsDescendantOf(workspace) then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for i, part in parts do
			part.CFrame = frames[i]
		end
	end
end

return PetModels
