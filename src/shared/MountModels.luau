--!strict
-- Modelos de las monturas (Data/Mounts): animales voxel que el jugador monta. Cajas alineadas en
-- celdas de CELL studs, con el suelo en y = 0 y el frente hacia -Z, alrededor de una pieza invisible
-- "Root" en el suelo, bajo el centro del cuerpo (el pivote).
-- Articulado para las animaciones (KeyframeSequence, con un AnimationController): cada hueso es una
-- pieza invisible con su nombre ("Body", "Neck", "Head", "Jaw", "EarL", "Tail", "LegFL" y debajo
-- "ShinFL"…) colgada de su padre con un Motor6D en la articulación, y cada caja va soldada a su
-- hueso (atributo "Bone"). Las animaciones se enlazan por esos nombres.
-- El attachment "Seat" del hueso "Body" marca dónde se sienta el jinete (encima de la manta), y se
-- mueve con el lomo.

local Mounts = require(script.Parent.Data.Mounts)

local CELL = 0.2

type Kit = {
	-- Caja de la parte "bone" con su centro y su tamaño en celdas.
	box: (bone: string, name: string, center: Vector3, size: Vector3, color: Color3) -> BasePart,
	-- Posición en el modelo (studs, ya escalada) de una celda.
	at: (cell: Vector3) -> Vector3,
}

-- Lo que devuelve cada constructor: la celda del asiento y los huesos, cada uno después de su padre,
-- con la celda de su articulación.
type Built = {
	seat: Vector3,
	joints: { { bone: string, parent: string, pivot: Vector3 } },
	-- Celda de la boca, de donde sale el escupitajo (si la montura escupe).
	mouth: Vector3?,
}

local MountModels = {}

-- Colores de la manta y las borlas andinas (docs/img/LlamaVoxel.jfif). Studio aclara los tonos
-- saturados: van algo más oscuros que en la referencia.
local MAGENTA = Color3.fromRGB(215, 20, 125)
local RED = Color3.fromRGB(215, 25, 30)
local YELLOW = Color3.fromRGB(245, 200, 15)
local GREEN = Color3.fromRGB(25, 165, 55)

local builders: { [string]: (kit: Kit) -> Built } = {
	-- Llama Andina (docs/img/LlamaVoxel.jfif y las fotos de llamas de docs/img): lana blanca con la
	-- grupa, los muslos, la panza y las orejas negras, cuello largo, orejas altas que se curvan hacia
	-- dentro como un plátano, gafas de sol más anchas que la cabeza, collar de borlas y la manta
	-- tejida en marcos (rojo, amarillo, verde, rojo y magenta en el centro) con flecos rojos.
	Llama = function(k)
		local box = k.box
		local wool = Color3.fromRGB(228, 226, 220)
		local speck = Color3.fromRGB(198, 196, 192)
		local black = Color3.fromRGB(30, 28, 32)
		local hoof = Color3.fromRGB(48, 44, 48)
		local muzzle = Color3.fromRGB(208, 204, 200)
		local nose = Color3.fromRGB(95, 88, 90)
		local fluff = Color3.fromRGB(238, 236, 230)
		local cheek = Color3.fromRGB(196, 190, 186) -- sombra de la cara: cachetes, nariz y barbilla
		-- Bozal de cuerda turquesa, como el de las fotos (no verde: el verde es solo para curar).
		local halter = Color3.fromRGB(30, 150, 165)
		local frame = Color3.fromRGB(72, 60, 88)
		local lens = Color3.fromRGB(36, 30, 46)

		-- Cuerpo: tronco, pecho que baja delante, grupa negra y panza negra.
		box("Body", "Torso", Vector3.new(0, 15.5, 2), Vector3.new(7, 7, 18), wool)
		box("Body", "Chest", Vector3.new(0, 15.25, -7.5), Vector3.new(6.6, 7.5, 3), wool)
		box("Body", "Rump", Vector3.new(0, 15.3, 11.8), Vector3.new(6.6, 6.2, 2), black)
		box("Body", "Belly", Vector3.new(0, 11.5, 2), Vector3.new(5.4, 1.2, 15), black)
		-- Lo negro de atrás sube por los costados y el lomo detrás de la manta, con una mancha blanca.
		box("Body", "Haunch", Vector3.new(0, 15.6, 10), Vector3.new(7.24, 7.2, 2.2), black)
		box("Body", "Spot", Vector3.new(1.2, 19.25, 10.4), Vector3.new(2, 0.1, 1.2), wool)
		-- Por detrás (lo que ve el jugador), manchas blancas irregulares sobre la grupa negra: sin ellas
		-- la espalda era una losa negra.
		box("Body", "Spot", Vector3.new(-0.6, 14.3, 12.85), Vector3.new(2.6, 1.8, 0.1), wool)
		box("Body", "Spot", Vector3.new(0.7, 15.5, 12.85), Vector3.new(1.8, 1.2, 0.1), wool)
		box("Body", "Spot", Vector3.new(-2.2, 17.6, 12.85), Vector3.new(1.2, 0.9, 0.1), wool)
		for side = -1, 1, 2 do
			-- Mancha negra del codo, delante y abajo.
			box("Body", "Elbow", Vector3.new(side * 3.35, 12.9, -7.4), Vector3.new(0.12, 2.6, 3), black)
		end

		-- Patas blancas con la pezuña partida en dos dedos; las de atrás, con el muslo negro de la grupa.
		for _, leg in { { "F", -6.5, 2.6, 2.8 }, { "B", 9.6, 3, 3.6 } } do
			local key, z, upperW, upperD = leg[1] :: string, leg[2] :: number, leg[3] :: number, leg[4] :: number
			for side = -1, 1, 2 do
				local bone = `Leg{key}{if side < 0 then "L" else "R"}`
				local shin = `Shin{key}{if side < 0 then "L" else "R"}`
				local x = side * 2.3
				local back = if key == "B" then 0.4 else 0
				box(
					bone,
					"Thigh",
					Vector3.new(x, 9.6, z + back),
					Vector3.new(upperW, 5.6, upperD),
					if key == "B" then black else wool
				)
				box(shin, "Shin", Vector3.new(x, 4, z + back), Vector3.new(2.2, 6, 2.2), wool)
				-- Rodilla (corvejón en las de atrás): un bloque algo más ancho entre los dos tramos.
				box(shin, "Knee", Vector3.new(x, 7, z + back), Vector3.new(2.5, 1, 2.5), wool)
				if key == "B" then
					box(
						bone,
						"Spot",
						Vector3.new(x + side * 0.5, 8.2, z + back + 1.85),
						Vector3.new(1.4, 1.6, 0.1),
						wool
					)
				end
				for toe = -1, 1, 2 do
					box(shin, "Toe", Vector3.new(x + toe * 0.58, 0.55, z + back - 0.3), Vector3.new(1, 1.1, 2.6), hoof)
				end
			end
		end

		-- Cuello largo que se adelanta un poco al subir.
		box("Neck", "NeckBase", Vector3.new(0, 20, -7), Vector3.new(3.8, 7, 4.2), wool)
		box("Neck", "NeckTop", Vector3.new(0, 25.5, -7.8), Vector3.new(3.4, 5, 3.6), wool)
		-- Collar magenta con borlas que cuelgan delante del pecho: cinco columnas de tres pompones
		-- (rojo o magenta arriba, amarillo y verde), separadas para que no parezcan un solo bloque.
		box("Neck", "Collar", Vector3.new(0, 19.9, -7), Vector3.new(4.4, 1.4, 4.8), MAGENTA)
		for i = 1, 5 do
			local x = (i - 3) * 1.05
			-- Las de los lados y el centro, un pompón más largas: escalonadas, como flecos.
			local stripes = if i % 2 == 1 then { RED, YELLOW, GREEN, MAGENTA } else { MAGENTA, YELLOW, GREEN }
			for row, color in stripes do
				box("Neck", "Tassel", Vector3.new(x, 19.65 - row * 0.95, -9.5), Vector3.new(0.85, 0.85, 0.85), color)
			end
		end

		-- Cabeza, hocico gris claro con la nariz y la boca, mechón de lana entre las orejas.
		box("Head", "Skull", Vector3.new(0, 29.5, -8.6), Vector3.new(4.4, 4.2, 5.2), wool)
		box("Head", "Muzzle", Vector3.new(0, 28.2, -12.6), Vector3.new(3.2, 2.8, 2.8), muzzle)
		-- Almohadilla de la nariz algo más oscura arriba del hocico, con las fosas nasales en ranura
		-- (dos bloques en diagonal que bajan hacia el centro, como las de la llama) y un brillo encima.
		box("Head", "NosePad", Vector3.new(0, 28.95, -14.05), Vector3.new(2.6, 1.2, 0.12), cheek)
		for side = -1, 1, 2 do
			box("Head", "Nostril", Vector3.new(side * 0.85, 29.15, -14.13), Vector3.new(0.35, 0.45, 0.1), nose)
			box("Head", "Nostril", Vector3.new(side * 0.55, 28.75, -14.13), Vector3.new(0.35, 0.45, 0.1), nose)
			box("Head", "NoseShine", Vector3.new(side * 0.85, 29.5, -14.13), Vector3.new(0.5, 0.15, 0.1), fluff)
			-- Labio de arriba partido: dos almohadillas a los lados de la raya del centro.
			box("Jaw", "Lip", Vector3.new(side * 0.75, 27.65, -14.15), Vector3.new(1.2, 0.8, 0.3), muzzle)
			-- Cachetes marcados: abultan a los lados bajo las gafas, con el borde de arriba más claro.
			box("Head", "Cheek", Vector3.new(side * 2.42, 28.75, -9.9), Vector3.new(0.45, 1.5, 2.6), cheek)
			box("Head", "Cheek", Vector3.new(side * 2.45, 29.65, -10), Vector3.new(0.45, 0.35, 2.1), fluff)
		end
		-- Interior de la boca: lo tapan los labios y solo se ve cuando la mandíbula se abre (al escupir).
		box("Head", "MouthInside", Vector3.new(0, 27.4, -13.98), Vector3.new(2.4, 1, 0.1), Color3.fromRGB(80, 38, 48))
		box("Jaw", "Mouth", Vector3.new(0, 27.9, -14.12), Vector3.new(0.25, 1, 0.12), nose)
		box("Jaw", "Mouth", Vector3.new(0, 27.15, -14.12), Vector3.new(2.2, 0.2, 0.12), nose)
		-- Barbilla: un escalón bajo el hocico.
		box("Jaw", "Chin", Vector3.new(0, 26.55, -12.5), Vector3.new(2.6, 0.5, 2.4), cheek)
		box("Head", "Tuft", Vector3.new(0, 32, -8.4), Vector3.new(2, 0.8, 2), wool)
		-- Bozal: muserola alrededor del hocico, carrillera por el lado de la cabeza (bajo el cachete)
		-- hasta detrás de las orejas y la tira de la nuca por encima.
		box("Head", "Halter", Vector3.new(0, 29.75, -12), Vector3.new(3.4, 0.3, 0.6), halter)
		box("Head", "Halter", Vector3.new(0, 26.15, -12), Vector3.new(3.4, 0.3, 0.6), halter)
		box("Head", "Halter", Vector3.new(0, 31.65, -6.4), Vector3.new(4.6, 0.12, 0.5), halter)
		for side = -1, 1, 2 do
			box("Head", "Halter", Vector3.new(side * 1.65, 27.95, -12), Vector3.new(0.15, 3.9, 0.6), halter)
			box("Head", "Halter", Vector3.new(side * 2.25, 27.65, -8.8), Vector3.new(0.12, 0.4, 4.8), halter)
			box("Head", "Halter", Vector3.new(side * 2.25, 29.6, -6.4), Vector3.new(0.12, 4, 0.5), halter)
		end
		-- Gafas de sol: dos cristales oscuros, puente, barra de arriba y patillas hasta las orejas.
		for side = -1, 1, 2 do
			box("Head", "Lens", Vector3.new(side * 1.2, 30.4, -11.45), Vector3.new(1.9, 1.2, 0.5), lens)
			box("Head", "Shine", Vector3.new(side * 1.2 - 0.45, 30.7, -11.72), Vector3.new(0.4, 0.3, 0.06), muzzle)
			box("Head", "Temple", Vector3.new(side * 2.35, 31, -9.45), Vector3.new(0.3, 0.35, 3.5), frame)
		end
		box("Head", "Brow", Vector3.new(0, 31.15, -11.5), Vector3.new(4.8, 0.4, 0.6), frame)
		box("Head", "Bridge", Vector3.new(0, 30.6, -11.45), Vector3.new(0.6, 0.35, 0.5), frame)
		-- Orejas negras en tres tramos que se cierran hacia arriba (forma de plátano), claras por dentro.
		for side = -1, 1, 2 do
			local ear = if side < 0 then "EarL" else "EarR"
			box(ear, "Ear", Vector3.new(side * 1.55, 33, -7.2), Vector3.new(1.2, 2.8, 1), black)
			box(ear, "Ear", Vector3.new(side * 1.25, 35.3, -7.4), Vector3.new(1.1, 2.2, 0.9), black)
			box(ear, "Ear", Vector3.new(side * 0.95, 36.6, -7.5), Vector3.new(0.9, 0.8, 0.8), black)
			box(ear, "EarInner", Vector3.new(side * 1.5, 33.4, -7.75), Vector3.new(0.6, 2.6, 0.1), muzzle)
			-- Pompones colgando de la base de la oreja, por fuera.
			box("Head", "Pompom", Vector3.new(side * 2.35, 32.2, -7), Vector3.new(0.8, 0.8, 0.8), MAGENTA)
			box("Head", "Pompom", Vector3.new(side * 2.35, 31.45, -7), Vector3.new(0.7, 0.7, 0.7), YELLOW)
		end

		-- Cola negra corta enroscada hacia arriba.
		box("Tail", "TailTuft", Vector3.new(0, 18, 13), Vector3.new(2, 2, 2), black)
		box("Tail", "TailTuft", Vector3.new(0, 19.8, 13.6), Vector3.new(1.8, 2, 1.6), black)
		box("Tail", "TailTuft", Vector3.new(0, 20.6, 12.7), Vector3.new(1.6, 1.2, 1.4), black)

		-- Manta: placa de base roja sobre el lomo y los costados, y encima marcos cada vez más
		-- pequeños, uno sobre otro (0,1 celdas cada uno). Por los lados, abiertos arriba, siguen en el lomo.
		local front, back, bottom, top, half = -4, 8.5, 13.4, 19.4, 3.9
		local z = (front + back) / 2
		box("Body", "Blanket", Vector3.new(0, top - 0.2, z), Vector3.new(half * 2, 0.4, back - front), RED)
		for side = -1, 1, 2 do
			box(
				"Body",
				"Blanket",
				Vector3.new(side * (half - 0.2), (bottom + top) / 2, z),
				Vector3.new(0.4, top - bottom, back - front),
				RED
			)
		end
		local frames = { { YELLOW, 0.8 }, { GREEN, 1.4 }, { RED, 2 }, { MAGENTA, 2.4 } }
		for i, layer in frames do
			local color, inset = layer[1] :: Color3, layer[2] :: number
			local face = top + 0.1 * (i - 1) -- donde se apoya este marco (arriba y a los lados)
			local side = half + 0.1 * (i - 1)
			local length = back - front - inset * 2
			box("Body", "Blanket", Vector3.new(0, face + 0.05, z), Vector3.new((side + 0.1) * 2, 0.1, length), color)
			for sign = -1, 1, 2 do
				local low = bottom + inset
				local high = face + 0.1
				box(
					"Body",
					"Blanket",
					Vector3.new(sign * (side + 0.05), (low + high) / 2, z),
					Vector3.new(0.1, high - low, length),
					color
				)
			end
		end
		-- Rombos andinos tejidos en el centro magenta de cada costado: rombo amarillo pequeño en escalones
		-- (una caja cuadrada y dos barras en cruz). En el lomo no van: los tapa el jinete.
		local surface = half + 0.45 -- sobre la cara de fuera del marco magenta
		for side = -1, 1, 2 do
			for _, rz in { -0.25, 2.25, 4.75 } do
				local center = Vector3.new(side * surface, 17.8, rz)
				box("Body", "Rhombus", center, Vector3.new(0.1, 1.1, 1.1), YELLOW)
				box("Body", "Rhombus", center, Vector3.new(0.1, 0.4, 1.8), YELLOW)
				box("Body", "Rhombus", center, Vector3.new(0.1, 1.8, 0.4), YELLOW)
			end
		end
		-- Flecos rojos en el borde de abajo.
		for side = -1, 1, 2 do
			for fz = front + 0.6, back - 0.5, 1.1 do
				box("Body", "Fringe", Vector3.new(side * 3.7, 12.95, fz), Vector3.new(0.45, 0.9, 0.6), RED)
			end
		end

		-- Motas grises de la lana en el cuello (semilla fija: todas las llamas iguales).
		local rng = Random.new(7)
		for _ = 1, 6 do
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local y = rng:NextNumber(17.5, 27)
			local width = if y > 23 then 1.7 else 1.9
			box(
				"Neck",
				"Speck",
				Vector3.new(side * (width + 0.05), y, rng:NextNumber(-9, -6)),
				Vector3.new(0.1, 0.8, 1.4),
				speck
			)
		end
		-- Pecho lanudo: dos mechones más claros que se escalonan bajo las borlas.
		box("Body", "Fluff", Vector3.new(0, 13, -9.2), Vector3.new(5, 1.6, 0.4), fluff)
		box("Body", "Fluff", Vector3.new(0, 11.9, -9.1), Vector3.new(3.6, 1, 0.4), fluff)

		-- Articulaciones: lomo en su centro, cuello en la base, cabeza en lo alto del cuello, mandíbula
		-- detrás del hocico (mastica de lado), orejas en su base, cola en la grupa, y cada pata en el
		-- hombro o la cadera con la caña en la rodilla.
		local joints = {
			{ bone = "Body", parent = "Root", pivot = Vector3.new(0, 15.5, 1) },
			{ bone = "Neck", parent = "Body", pivot = Vector3.new(0, 18, -7) },
			{ bone = "Head", parent = "Neck", pivot = Vector3.new(0, 27.5, -7.8) },
			{ bone = "Jaw", parent = "Head", pivot = Vector3.new(0, 27, -11.4) },
			{ bone = "EarL", parent = "Head", pivot = Vector3.new(-1.55, 31.6, -7.2) },
			{ bone = "EarR", parent = "Head", pivot = Vector3.new(1.55, 31.6, -7.2) },
			{ bone = "Tail", parent = "Body", pivot = Vector3.new(0, 18, 12.5) },
		}
		for _, leg in { { "F", -6.5 }, { "B", 10 } } do
			for side = -1, 1, 2 do
				local name = `{leg[1]}{if side < 0 then "L" else "R"}`
				local x, lz = side * 2.3, leg[2] :: number
				table.insert(joints, { bone = `Leg{name}`, parent = "Body", pivot = Vector3.new(x, 12, lz) })
				table.insert(joints, { bone = `Shin{name}`, parent = `Leg{name}`, pivot = Vector3.new(x, 7, lz) })
			end
		end
		return { seat = Vector3.new(0, top + 0.4, 2), joints = joints, mouth = Vector3.new(0, 27.4, -14.4) }
	end,
}

-- Construye la montura "mountId": Root anclada y el resto colgando de ella por las articulaciones,
-- sin colisión (quien la use decide cómo moverla: desanclar Root y soldarla, o moverla con PivotTo).
function MountModels.build(mountId: string): Model?
	local mount = Mounts[mountId]
	local builder = builders[mountId]
	if not (mount and builder) then
		return nil
	end
	local scale = CELL * mount.size
	local model = Instance.new("Model")
	model.Name = `Montura_{mountId}`
	local function at(cell: Vector3): Vector3
		return cell * scale
	end
	local function place(name: string, size: Vector3, position: Vector3, color: Color3): BasePart
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = CFrame.new(position)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.Parent = model
		return part
	end
	local root = place("Root", Vector3.one * 0.2, Vector3.zero, Color3.new(1, 1, 1))
	root.Transparency = 1
	root.CastShadow = false
	model.PrimaryPart = root
	local boxes: { BasePart } = {}
	local built = builder({
		at = at,
		box = function(bone, name, center, size, color)
			local part = place(name, size * scale, at(center), color)
			part:SetAttribute("Bone", bone)
			table.insert(boxes, part)
			return part
		end,
	})
	-- Huesos: pieza invisible en la articulación, con un Motor6D desde la de su padre.
	local bones: { [string]: BasePart } = { Root = root }
	for _, item in built.joints do
		local bone = place(item.bone, Vector3.one * 0.2, at(item.pivot), Color3.new(1, 1, 1))
		bone.Transparency = 1
		bone.CastShadow = false
		bone.Anchored = false
		local parent = bones[item.parent]
		local motor = Instance.new("Motor6D")
		motor.Name = `{item.bone}Joint`
		motor.Part0 = parent
		motor.Part1 = bone
		motor.C0 = parent.CFrame:ToObjectSpace(bone.CFrame)
		motor.Parent = parent
		bones[item.bone] = bone
	end
	for _, part in boxes do
		local bone = bones[part:GetAttribute("Bone") :: string]
		part.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = bone
		weld.Part1 = part
		weld.Parent = part
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Seat"
	attachment.CFrame = bones.Body.CFrame:ToObjectSpace(CFrame.new(at(built.seat)))
	attachment.Parent = bones.Body
	if built.mouth then
		-- Escupitajo: un chorro de gotas que sale hacia delante de la cabeza y cae con la gravedad.
		-- Blanco azulado, como la saliva (ni verde, que es la curación, ni morado, que es el veneno).
		-- Velocidades muy distintas para que las gotas se estiren en un chorro: con todas parecidas
		-- salía una bola de nube delante de la boca.
		local mouth = Instance.new("Attachment")
		mouth.Name = "SpitPoint"
		mouth.CFrame = bones.Head.CFrame:ToObjectSpace(CFrame.new(at(built.mouth)))
		mouth.Parent = bones.Head
		local spit = Instance.new("ParticleEmitter")
		spit.Name = "Spit"
		spit.Enabled = false
		spit.Rate = 0
		spit.EmissionDirection = Enum.NormalId.Front
		spit.SpreadAngle = Vector2.new(6, 6)
		spit.Speed = NumberRange.new(5 * mount.size, 28 * mount.size)
		spit.Acceleration = Vector3.new(0, -30, 0)
		spit.Drag = 1.5
		spit.Lifetime = NumberRange.new(0.35, 0.6)
		spit.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2 * mount.size),
			NumberSequenceKeypoint.new(1, 0.08 * mount.size),
		})
		spit.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.7, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		spit.Color = ColorSequence.new(Color3.fromRGB(235, 245, 250), Color3.fromRGB(190, 215, 230))
		spit.LightEmission = 0.2
		spit.LightInfluence = 0.6
		spit.Parent = mouth
	end
	local controller = Instance.new("AnimationController")
	Instance.new("Animator").Parent = controller
	controller.Parent = model
	return model
end

-- Lanza el escupitajo de la montura (en el marcador "Escupir" de su animación). No hace nada si la
-- montura no escupe.
function MountModels.spit(model: Model, amount: number?)
	local spit = model:FindFirstChild("Spit", true)
	if spit and spit:IsA("ParticleEmitter") then
		spit:Emit(amount or 28)
	end
end

return MountModels
