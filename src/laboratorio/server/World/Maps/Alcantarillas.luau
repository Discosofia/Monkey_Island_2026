--!strict
-- Mapa "Alcantarillas" del Laboratorio en ruinas (Fase 13, L4b bloque C; docs/LABORATORIO.md §4): la red de
-- desagüe del Proyecto PRIMAL, comida por la selva. Favorece la corta distancia: túneles de 10 de ancho y
-- ninguna línea recta pasa de unos 30 studs. Voxel: bloques en rejilla con pocos tonos planos (hormigón gris,
-- metal oxidado, cristal azulado roto, cables, raíces; nunca verde brillante, que es el de la curación).
-- Lo construye World/LabBuilder dentro de Workspace.LabMap.Alcantarillas.
--
-- Forma: caja CERRADA de 140 × 100 studs (más los muros), en coordenadas locales (el suelo en y = 0, simétrico
-- de oeste a este): suelo, techo y muros opacos, sin cielo. Por dentro (todo a 14 de alto salvo la sala de
-- bombas, a 20):
--   - Zonas de salida (|x| 56–70): al oeste los Piratas (tablones, faroles) y al este los Guardianes (esclusa
--     blanca, focos). Sus bocas (|z| 2–8) dan a los colectores.
--   - Colectores (|x| 44–56, |z| ≤ 40): unen las bocas con los túneles norte y sur. Tienen muros rotos
--     alternados (medio cuerpo de alto) para cortar la vista a lo largo.
--   - Túnel principal (|z| ≤ 5, |x| 16–44) con dos compuertas oxidadas a medio abrir en zigzag (|x| 32 cubre
--     z -5…0 y |x| 24 cubre z 0…5): ninguna línea de tiro pasa de unos 30 studs.
--   - Sala de bombas (|x|, |z| ≤ 16, techo a 20): una bomba grande en el centro (8 × 12, cubre todo el ancho
--     del túnel principal) y cuatro pequeñas en (±8, ±8),
--     con tuberías de suelo y válvulas macizas. Entradas: el túnel principal (este y oeste) y los pasos norte
--     y sur (|x| ≤ 4, z 16–30).
--   - Túneles norte y sur (|z| 30–40, |x| ≤ 44) con haces de tuberías macizos que obligan a zigzaguear.
--   - Todo lo demás es relleno macizo y opaco, del suelo al techo.
--   - El agua es una lámina decorativa a los tobillos (sin choque ni consulta: no se nada).
--
-- Piezas con nombre que lee el código: "Bases/<bando>" (LabParts.buildZone), "Derrumbes" (tapones de cascotes
-- en las entradas del túnel sur y en el paso sur hacia la sala de bombas: cierran el túnel sur en 1v1 y 2v2;
-- sin barreras invisibles dentro, LabWorldService.setFormat les pone el choque), "SpawnsLibres"
-- (LabParts.buildFreeSpawns) y "Techo" (losas macizas y todo lo que cuelga de ellas: el espectador lo oculta
-- en local en la vista cenital, LabSpectateController).
--
-- Reglas de las piezas: todo lo que un jugador puede tocar (base a 8 o menos) y sobresale es macizo (block /
-- hard); el decorado (sin choque ni rayos) es pintura plana, luces, agua, cables, lianas y lo inalcanzable. No
-- hay muros invisibles: el mapa es cerrado y no tiene caídas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LabMapModels = require(ReplicatedStorage.Shared.LabMapModels)
local LabParts = require(script.Parent.Parent.LabParts)

local PALETTE = LabMapModels.PALETTE
local CONCRETE = PALETTE.CONCRETE
local CONCRETE_LIGHT = PALETTE.CONCRETE_LIGHT
local CONCRETE_DARK = PALETTE.CONCRETE_DARK
local RUST = PALETTE.RUST
local RUST_DARK = PALETTE.RUST_DARK
local STEEL = PALETTE.STEEL
local STEEL_DARK = PALETTE.STEEL_DARK
local GLASS = PALETTE.GLASS
local SERUM = PALETTE.SERUM
local CABLE = PALETTE.CABLE
local HAZARD = PALETTE.HAZARD
local VINE_DARK = PALETTE.VINE_DARK
local WOOD_DARK = PALETTE.WOOD_DARK
local WATER = PALETTE.WATER

-- Medidas de las zonas de salida y los muros (LabParts.buildZone). El suelo está en y = 0.
local GEOMETRY: LabParts.Geometry = {
	halfX = 56, -- la boca de las zonas de salida
	outerX = 70, -- el fondo de las zonas de salida
	halfZ = 10,
	mouthFrom = 2, -- cada boca de la zona va de |z| 2 a 8
	mouthTo = 8,
	wallHeight = 14,
	ceiling = 14,
	gateHeight = 10,
}

-- Sótano cerrado: poca luz de ambiente (los focos enjaulados hacen el resto), sin bruma verde y con la
-- corrección de color un punto más clara para que se vea en el teléfono. Sin verdes en la corrección.
local LIGHTING: LabParts.LightingPreset = {
	clockTime = 14,
	latitude = 10,
	brightness = 1,
	ambient = Color3.fromRGB(70, 76, 86),
	outdoorAmbient = Color3.fromRGB(40, 44, 50),
	atmosphere = {
		density = 0.45,
		offset = 0,
		color = Color3.fromRGB(108, 116, 130),
		decay = Color3.fromRGB(64, 70, 82),
		glare = 0,
		haze = 1,
	},
	colorCorrection = { brightness = 0.03, contrast = 0.06, saturation = -0.05, tint = Color3.fromRGB(238, 242, 250) },
}

-- Semilla del decorado al azar (tonos, raíces, lianas, cascotes): el mismo mapa en cada construcción.
local SEED = 3303
-- Altura de la vista cenital del espectador (LabSpectateController) sobre el centro del mapa y cuánto se
-- desplaza hacia atrás (z): con el techo oculto se ve el mapa entero desde justo encima, a 120. Sin
-- desplazamiento, las paredes de 14 casi no tapan el suelo.
local OVERHEAD_HEIGHT = 120
local OVERHEAD_BACK = 0

type Rect = { number } -- { x1, z1, x2, z2 }

local CEILING = GEOMETRY.ceiling -- el techo de los túneles (la cara de abajo de la losa)
local PUMP_CEILING = 20 -- el techo de la sala de bombas
local SLAB = 2 -- grueso de las losas del techo
local COLLAPSE_HEIGHT = 13.5 -- los cascotes miden de 9,5 a 13,5: más que el salto
local LAMP_COLOR = Color3.fromRGB(255, 222, 160)

-- Suelos transitables, sin solaparse (las baldosas de 8 × 8 de cada uno): el túnel principal, los colectores,
-- los túneles norte y sur, la sala de bombas y los dos pasos.
local WALKABLE: { Rect } = {
	{ 16, -5, 44, 5 },
	{ -44, -5, -16, 5 },
	{ 44, -40, 56, 40 },
	{ -56, -40, -44, 40 },
	{ -44, 30, 44, 40 },
	{ -44, -40, 44, -30 },
	{ -16, -16, 16, 16 },
	{ -4, 16, 4, 30 },
	{ -4, -30, 4, -16 },
}
local PUMP_INDEX = 7 -- la sala de bombas dentro de WALKABLE (su techo está a 20)

-- Relleno macizo y opaco (un cuadrante; se refleja en los cuatro): lo que no son túneles. Del suelo al techo.
local FILLS: { Rect } = {
	{ 16, 5, 44, 30 }, -- entre el túnel principal y el norte
	{ 4, 16, 16, 30 }, -- entre la sala de bombas y el túnel norte, junto al paso
	{ 56, 12, 72, 52 }, -- detrás de los colectores, junto a la zona de salida
	{ 0, 40, 56, 52 }, -- el muro de más allá del túnel norte
}

-- Caras de los muros que se ven desde dentro (un cuadrante): { eje, coordenada, desde, hasta, hacia dónde
-- está el hueco (+1 o -1) }. Reciben franjas planas y alguna liana.
local FACES: { { any } } = {
	{ "z", 5, 16, 44, -1 },
	{ "x", 44, 5, 30, 1 },
	{ "z", 30, 4, 44, 1 },
	{ "z", 40, 0, 56, -1 },
	{ "x", 56, 12, 40, -1 },
	{ "x", 4, 16, 30, -1 },
	{ "x", 16, 5, 16, -1 },
	{ "z", 16, 4, 16, -1 },
}

-- Puntos de aparición libres (Todos contra todos), simétricos y sin nada que choque a ±3:
--   (±11, 0)    sala de bombas, junto a las entradas este y oeste (la bomba grande llega a x 4,3 y las pequeñas
--               a z 5,7)
--   (0, ±12)    sala de bombas, dentro de los pasos norte y sur (bomba grande hasta z 6,3, muro en 16)
--   (±50, ±22)  colectores, entre los muros rotos (z 15–17, con sus escombros hasta 18,8) y el tapón del
--               derrumbe (z -30…-26) o el muro de 34
--   (±30, 35)   túnel norte, entre los haces de |x| 20 y 40
--   (±30, -35)  túnel sur (los cubre el derrumbe)
local FREE_SPAWNS: { LabParts.FreeSpawnPoint } = {
	{ x = -11, z = 0 },
	{ x = 11, z = 0 },
	{ x = 0, z = -12 },
	{ x = 0, z = 12 },
	{ x = -50, z = -22 },
	{ x = 50, z = -22 },
	{ x = -50, z = 22 },
	{ x = 50, z = 22 },
	{ x = -30, z = 35 },
	{ x = 30, z = 35 },
	{ x = -30, z = -35, closable = true },
	{ x = 30, z = -35, closable = true },
}

local block = LabParts.block
local between = LabParts.between
local decor = LabParts.decor
local solid = LabParts.solid
local tone = LabParts.tone
local hazardStripe = LabParts.hazardStripe
local cable = LabParts.cable
local vine = LabParts.vine
local crate = LabParts.crate

-- Pieza decorativa (sin choque ni rayos).
local function deco(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance
): BasePart
	return decor(block(name, size, cframe, color, material, parent))
end

-- Pieza maciza que sobresale (choca y la encuentran los rayos).
local function hard(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance
): BasePart
	return solid(block(name, size, cframe, color, material, parent))
end

local function folder(parent: Instance, name: string): Folder
	local result = Instance.new("Folder")
	result.Name = name
	result.Parent = parent
	return result
end

-- Llama a "fn" con el rectángulo del cuadrante reflejado en los cuatro (esquinas ordenadas).
local function quadrants(rect: Rect, fn: (x1: number, z1: number, x2: number, z2: number, sx: number, sz: number) -> ())
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local ax, bx = sx * rect[1], sx * rect[3]
			local az, bz = sz * rect[2], sz * rect[4]
			fn(math.min(ax, bx), math.min(az, bz), math.max(ax, bx), math.max(az, bz), sx, sz)
		end
	end
end

-- Cortes de un eje cada "step".
local function cuts(from: number, to: number, step: number): { number }
	local list = { from }
	local at = from + step
	while at < to - 0.01 do
		table.insert(list, at)
		at += step
	end
	table.insert(list, to)
	return list
end

-- Suelo, relleno macizo y muros exteriores.
local function buildShell(model: Model)
	local floor = folder(model, "Suelo")
	-- Baldosas de 8 × 8 en dos tonos sobre los suelos transitables (cara de arriba en y = 0).
	for _, rect in WALKABLE do
		local xs, zs = cuts(rect[1], rect[3], 8), cuts(rect[2], rect[4], 8)
		for ix = 1, #xs - 1 do
			for iz = 1, #zs - 1 do
				local color = if (ix + iz) % 2 == 0 then CONCRETE_LIGHT else CONCRETE
				local tile = between(
					"Baldosa",
					xs[ix],
					zs[iz],
					xs[ix + 1],
					zs[iz + 1],
					-1,
					1,
					tone(color, 0.12),
					Enum.Material.Concrete,
					floor
				)
				tile.Locked = true
			end
		end
	end
	-- Relleno: del suelo (-1) al techo (CEILING), opaco.
	local fills = folder(model, "Relleno")
	for _, rect in FILLS do
		quadrants(rect, function(x1, z1, x2, z2)
			local part =
				between("Relleno", x1, z1, x2, z2, -1, CEILING + 1, tone(CONCRETE, 0.14), Enum.Material.Concrete, fills)
			part.Locked = true
		end)
	end
	-- Muro exterior detrás de las zonas de salida (la de los Piratas acaba en una barrera invisible a x 70–72).
	local outer = folder(model, "MuroExterior")
	for _, sideX in { -1, 1 } do
		local part = between(
			"Muro",
			sideX * 72,
			-52,
			sideX * 74,
			52,
			-1,
			CEILING + SLAB + 1,
			CONCRETE_DARK,
			Enum.Material.Concrete,
			outer
		)
		part.Locked = true
	end
end

-- Las losas del techo y todo lo que cuelga de ellas van en "Techo": el espectador lo oculta en local.
local function buildCeiling(model: Model): Folder
	local ceiling = folder(model, "Techo")
	-- Losa de 14 a 16 sobre todo menos la sala de bombas.
	local slabs: { Rect } = {
		{ -72, 17, 72, 52 },
		{ -72, -52, 72, -17 },
		{ 17, -17, 72, 17 },
		{ -72, -17, -17, 17 },
	}
	for _, rect in slabs do
		local part = between(
			"Losa",
			rect[1],
			rect[2],
			rect[3],
			rect[4],
			CEILING,
			SLAB,
			tone(CONCRETE_DARK, 0.1),
			Enum.Material.Concrete,
			ceiling
		)
		part.Locked = true
	end
	-- La sala de bombas: cuatro muros de 14 a 20 y su techo (de 20 a 22).
	for _, sideX in { -1, 1 } do
		between(
			"MuroSala",
			sideX * 16,
			-17,
			sideX * 17,
			17,
			CEILING,
			PUMP_CEILING - CEILING,
			CONCRETE_DARK,
			Enum.Material.Concrete,
			ceiling
		)
	end
	for _, sideZ in { -1, 1 } do
		between(
			"MuroSala",
			-16,
			sideZ * 16,
			16,
			sideZ * 17,
			CEILING,
			PUMP_CEILING - CEILING,
			CONCRETE_DARK,
			Enum.Material.Concrete,
			ceiling
		)
	end
	between("TechoSala", -17, -17, 17, 17, PUMP_CEILING, SLAB, CONCRETE_DARK, Enum.Material.Concrete, ceiling)
	return ceiling
end

-- Lámina de agua a los tobillos: solo decorado, nada que haga nadar.
local function buildWater(model: Model)
	local water = folder(model, "Agua")
	for _, rect in WALKABLE do
		local sheet = deco(
			"Agua",
			Vector3.new(rect[3] - rect[1], 0.6, rect[4] - rect[2]),
			CFrame.new((rect[1] + rect[3]) / 2, 0.3, (rect[2] + rect[4]) / 2),
			WATER,
			Enum.Material.SmoothPlastic,
			water
		)
		sheet.Transparency = 0.35
		sheet.CastShadow = false
	end
end

-- Pintura plana en los muros (franjas de 0,1), reguero de óxido y lianas por las grietas.
local function buildFaces(model: Model)
	local faces = folder(model, "Muros")
	local rng = LabParts.rng
	for _, face in FACES do
		local axis, at, from, to, sign =
			face[1] :: string, face[2] :: number, face[3] :: number, face[4] :: number, face[5] :: number
		-- La cara es un rectángulo sin grosor (en el eje del muro, "at").
		local line: Rect = if axis == "z" then { from, at, to, at } else { at, from, at, to }
		quadrants(line, function(x1, z1, x2, z2, sx, sz)
			-- A cada cuadrante le toca la cara reflejada: el hueco mira a "sign" en el eje del muro.
			local normal = if axis == "z" then Vector3.new(0, 0, sign * sz) else Vector3.new(sign * sx, 0, 0)
			local length = if axis == "z" then x2 - x1 else z2 - z1
			local mid = if axis == "z" then (x1 + x2) / 2 else (z1 + z2) / 2
			local plane = if axis == "z" then z1 else x1
			local function put(name: string, y: number, height: number, color: Color3, along: number, size: number)
				local dims = if axis == "z" then Vector3.new(size, height, 0.1) else Vector3.new(0.1, height, size)
				local center = if axis == "z"
					then Vector3.new(along, y + height / 2, plane + normal.Z * 0.05)
					else Vector3.new(plane + normal.X * 0.05, y + height / 2, along)
				deco(name, dims, CFrame.new(center), color, nil, faces)
			end
			put("Zocalo", 0, 1.3, STEEL_DARK, mid, length - 0.4)
			put("Banda", 6.6, 0.6, RUST_DARK, mid, length - 0.4)
			put("Cornisa", 12.6, 0.6, STEEL_DARK, mid, length - 0.4)
			-- Regueros de óxido que bajan de la banda.
			for _ = 1, math.floor(length / 6) do
				if rng:NextNumber() < 0.6 then
					local drop = rng:NextNumber(3, 6)
					put(
						"Reguero",
						6.6 - drop,
						drop,
						tone(RUST, 0.3),
						mid + rng:NextNumber(-0.5, 0.5) * (length - 2),
						0.5
					)
				end
			end
			-- Lianas por las grietas del techo.
			for _ = 1, math.floor(length / 10) do
				if rng:NextNumber() < 0.75 then
					local along = mid + rng:NextNumber(-0.5, 0.5) * (length - 2)
					local top = if axis == "z"
						then Vector3.new(along, CEILING - 0.2, plane)
						else Vector3.new(plane, CEILING - 0.2, along)
					vine(faces, top, normal, rng:NextNumber(4, 10))
				end
			end
		end)
	end
end

-- Compuerta oxidada a medio abierta: la hoja cubre z1..z2 (hasta el muro) y deja el resto libre.
local function sluice(parent: Instance, x: number, z1: number, z2: number)
	local width = z2 - z1
	local centerZ = (z1 + z2) / 2
	block(
		"Compuerta",
		Vector3.new(1.6, 12, width),
		CFrame.new(x, 6, centerZ),
		RUST_DARK,
		Enum.Material.CorrodedMetal,
		parent
	)
	-- El dintel cruza todo el túnel bajo el techo.
	block("Dintel", Vector3.new(1.8, 2, 10), CFrame.new(x, 13, 0), STEEL_DARK, Enum.Material.Metal, parent)
	-- Bandas planas de óxido y el borde de peligro del lado abierto.
	for _, y in { 3, 8 } do
		deco(
			"Banda",
			Vector3.new(1.8, 0.7, width),
			CFrame.new(x, y, centerZ),
			RUST,
			Enum.Material.CorrodedMetal,
			parent
		)
	end
	local openSide = if z1 < -4 then 1 else -1
	for index = 0, 5 do
		deco(
			"Peligro",
			Vector3.new(1.8, 2, 0.1),
			CFrame.new(x, 1 + index * 2, centerZ + openSide * (width / 2 + 0.05)),
			if index % 2 == 0 then HAZARD else CABLE,
			nil,
			parent
		)
	end
	-- Las ruedas de las dos caras (macizas: están al alcance).
	for _, side in { -1, 1 } do
		hard(
			"Rueda",
			Vector3.new(0.6, 1.8, 1.8),
			CFrame.new(x + side * 1.1, 6, centerZ - openSide * 1),
			RUST,
			Enum.Material.Metal,
			parent
		)
		hard(
			"Eje",
			Vector3.new(0.5, 0.5, 0.5),
			CFrame.new(x + side * 0.8, 6, centerZ - openSide * 1),
			STEEL_DARK,
			nil,
			parent
		)
	end
end

-- Túnel principal: las compuertas en zigzag, sin solape (la de |x| 32 cubre z -5…0 y la de |x| 24 cubre z
-- 0…5: 5 libres en cada una) y cajas contra el muro que dejan 7 libres (|x| 40 cubre z -5…-2 y |x| 20 cubre
-- z 2…5, del lado que ya tapa la compuerta).
local function buildMainTunnel(model: Model)
	local main = folder(model, "TunelPrincipal")
	for _, sideX in { -1, 1 } do
		sluice(main, sideX * 32, -5, 0)
		sluice(main, sideX * 24, 0, 5)
		crate(main, Vector3.new(sideX * 40, 0, -3.5), 3, RUST_DARK)
		crate(main, Vector3.new(sideX * 40, 3, -3.5), 2, STEEL)
		crate(main, Vector3.new(sideX * 20, 0, 3.5), 3, STEEL)
	end
end

-- Haz de tuberías (cobertura de suelo a techo) entre z1 y z2 y de ±2 en x: núcleo, aros y las tuberías sueltas.
local function pipeBundle(parent: Instance, x: number, z1: number, z2: number)
	local width = z2 - z1
	local centerZ = (z1 + z2) / 2
	block(
		"Haz",
		Vector3.new(3.6, CEILING, width - 0.4),
		CFrame.new(x, CEILING / 2, centerZ),
		STEEL_DARK,
		Enum.Material.Metal,
		parent
	)
	for _, y in { 2, 5, 8, 11 } do
		block("Aro", Vector3.new(4, 0.6, width), CFrame.new(x, y, centerZ), RUST, Enum.Material.CorrodedMetal, parent)
	end
	-- Una tubería gorda en cada cara larga, también maciza.
	for _, side in { -1, 1 } do
		block(
			"Tuberia",
			Vector3.new(0.5, CEILING, 3.4),
			CFrame.new(x + side * 2.05, CEILING / 2, centerZ),
			RUST_DARK,
			Enum.Material.CorrodedMetal,
			parent
		)
	end
end

-- Túneles norte y sur: haces alternados (uno alto de z 34,5–40 y el siguiente bajo de z 30–35,5, de 5,5 de
-- fondo) que obligan a zigzaguear: cada uno deja 4,5 libres, se solapan 1 en z para que no haya línea recta y
-- entre dos haces seguidos queda 4,4 en x (esquina con esquina, 4,5 en diagonal). Sin cajas en medio.
local function buildSideTunnels(model: Model)
	local tunnels = folder(model, "TunelesNorteSur")
	for _, sideZ in { -1, 1 } do
		-- Cada haz: { x, z1, z2 } del lado norte; el sur es su espejo.
		for _, bundle in
			{
				{ 0, 34.5, 40 },
				{ -9, 30, 35.5 },
				{ 9, 30, 35.5 },
				{ -20, 34.5, 40 },
				{ 20, 34.5, 40 },
				{ -40, 30, 35.5 },
				{ 40, 30, 35.5 },
			}
		do
			local z1, z2 = sideZ * bundle[2], sideZ * bundle[3]
			pipeBundle(tunnels, bundle[1], math.min(z1, z2), math.max(z1, z2))
		end
	end
end

-- Muros rotos de los colectores (medio cuerpo de alto, con hierros y escombros): cortan la vista a lo largo y
-- dejan 6 libres a un lado.
-- "awayZ" (-1 o 1) es la cara del muro (hacia -z o +z) que da a la zona ancha, no al paso: los escombros van
-- solo ahí, para no estrechar el paso a menos de 4.
local function brokenWall(parent: Instance, x1: number, z1: number, x2: number, z2: number, awayZ: number)
	local centerX, centerZ = (x1 + x2) / 2, (z1 + z2) / 2
	between("Muro", x1, z1, x2, z2, 0, 10, tone(CONCRETE, 0.12), Enum.Material.Concrete, parent)
	-- Los bloques sueltos de los dos extremos, macizos y apoyados en el suelo, en la cara que da a la zona ancha.
	for _, side in { -1, 1 } do
		local bx = centerX + side * (math.abs(x2 - x1) / 2 - 0.9)
		block(
			"Escombro",
			Vector3.new(1.8, 1.5, 1.8),
			CFrame.new(bx, 0.75, centerZ + awayZ * ((math.abs(z2 - z1) / 2) + 0.9)),
			CONCRETE_DARK,
			Enum.Material.Concrete,
			parent
		)
	end
	-- Hierros torcidos asomando por arriba (macizos, apoyados en el muro).
	for index = 1, 3 do
		local across = (index - 2) * math.abs(x2 - x1) / 4
		block(
			"Hierro",
			Vector3.new(0.4, 3, 0.4),
			CFrame.new(centerX + across, 10, centerZ)
				* CFrame.Angles(LabParts.rng:NextNumber(-0.3, 0.3), 0, LabParts.rng:NextNumber(-0.3, 0.3))
				* CFrame.new(0, 1.3, 0),
			RUST,
			Enum.Material.CorrodedMetal,
			parent
		)
	end
	deco(
		"Banda",
		Vector3.new(math.abs(x2 - x1) + 0.2, 0.6, math.abs(z2 - z1) + 0.2),
		CFrame.new(centerX, 5, centerZ),
		RUST_DARK,
		nil,
		parent
	)
end

local function buildCollectors(model: Model)
	local collectors = folder(model, "Colectores")
	for _, sideX in { -1, 1 } do
		for _, sideZ in { -1, 1 } do
			-- Dos muros escalonados junto a la boca (|z| 9–11 y 15–17): el paso entre ellos mide 4.
			brokenWall(collectors, sideX * 44, sideZ * 9, sideX * 50, sideZ * 11, -sideZ)
			brokenWall(collectors, sideX * 50, sideZ * 15, sideX * 56, sideZ * 17, sideZ)
			-- El de la entrada de los túneles norte y sur, a z 32–34: deja libres 6 de alto del paso (z 34–40).
			brokenWall(collectors, sideX * 44, sideZ * 32, sideX * 50, sideZ * 34, -sideZ)
		end
	end
end

-- La bomba grande del centro: 8 de ancho (x) × 10 de alto × 12 de fondo (z), con aros, motor y tubos que suben
-- al techo. Cubre todo el ancho del túnel principal (z ±6): no hay línea recta de boca a boca de la sala.
local function bigPump(parent: Instance, techo: Instance)
	block("Bomba", Vector3.new(8, 10, 12), CFrame.new(0, 5, 0), STEEL_DARK, Enum.Material.Metal, parent)
	for _, y in { 1.5, 5, 8.5 } do
		block("Aro", Vector3.new(8.6, 0.8, 12.6), CFrame.new(0, y, 0), RUST, Enum.Material.CorrodedMetal, parent)
	end
	block("Tapa", Vector3.new(6, 1.2, 8), CFrame.new(0, 10.6, 0), STEEL, Enum.Material.Metal, parent)
	block("Motor", Vector3.new(4, 3, 4), CFrame.new(0, 12.7, 0), RUST_DARK, Enum.Material.CorrodedMetal, parent)
	-- Los tubos del motor al techo de la sala (cuelgan de él: van con el Techo).
	for _, side in { -1, 1 } do
		deco(
			"Tubo",
			Vector3.new(1.2, PUMP_CEILING - 14.2, 1.2),
			CFrame.new(side * 1.2, (14.2 + PUMP_CEILING) / 2, 0),
			STEEL,
			Enum.Material.Metal,
			techo
		)
	end
	-- Manómetros pintados en las cuatro caras y ruedas de válvula macizas.
	for _, side in { -1, 1 } do
		deco("Manometro", Vector3.new(2, 2, 0.1), CFrame.new(0, 6.5, side * 6.05), CABLE, nil, parent)
		deco("Esfera", Vector3.new(1.4, 1.4, 0.1), CFrame.new(0, 6.5, side * 6.1), SERUM, Enum.Material.Neon, parent)
		deco("Manometro", Vector3.new(0.1, 2, 2), CFrame.new(side * 4.05, 6.5, 2), CABLE, nil, parent)
		hard("Rueda", Vector3.new(0.5, 1.8, 1.8), CFrame.new(side * 4.25, 3.5, -1.5), RUST, Enum.Material.Metal, parent)
	end
end

-- Una bomba pequeña de 4 × 6 × 4 en (x, z).
local function smallPump(parent: Instance, x: number, z: number)
	block("BombaPequena", Vector3.new(4, 6, 4), CFrame.new(x, 3, z), RUST_DARK, Enum.Material.CorrodedMetal, parent)
	for _, y in { 1.5, 4.5 } do
		block("Aro", Vector3.new(4.4, 0.5, 4.4), CFrame.new(x, y, z), STEEL_DARK, Enum.Material.Metal, parent)
	end
	block("Tapa", Vector3.new(4.6, 0.6, 4.6), CFrame.new(x, 6.3, z), STEEL, Enum.Material.Metal, parent)
	block("Eje", Vector3.new(0.5, 1, 0.5), CFrame.new(x, 7.1, z), STEEL_DARK, nil, parent)
	block("Volante", Vector3.new(2.4, 0.4, 2.4), CFrame.new(x, 7.8, z), RUST, Enum.Material.Metal, parent)
	-- Piloto pintado en la cara que mira a la bomba grande.
	deco(
		"Piloto",
		Vector3.new(0.1, 0.8, 0.8),
		CFrame.new(x - math.sign(x) * 2.05, 4, z),
		SERUM,
		Enum.Material.Neon,
		parent
	)
end

-- Sala de bombas: bombas, tuberías de suelo (macizas, de 1,6 de alto) con sus válvulas y lámparas en el techo.
local function buildPumpRoom(model: Model, techo: Folder)
	local room = folder(model, "SalaDeBombas")
	bigPump(room, techo)
	for _, sideX in { -1, 1 } do
		for _, sideZ in { -1, 1 } do
			smallPump(room, sideX * 8, sideZ * 8)
			-- La tubería de cada bomba pequeña baja al suelo y se junta con la de la grande, en la rendija entre
			-- las dos (x 4,25–5,75): así deja libres las entradas y los puntos de aparición.
			block(
				"Tuberia",
				Vector3.new(1.5, 1.6, 3.5),
				CFrame.new(sideX * 5, 0.8, sideZ * 7.75),
				RUST,
				Enum.Material.CorrodedMetal,
				room
			)
			-- Válvula sobre la tubería.
			hard("Vastago", Vector3.new(0.5, 1, 0.5), CFrame.new(sideX * 5, 2.1, sideZ * 7.75), STEEL_DARK, nil, room)
			hard(
				"Volante",
				Vector3.new(1.4, 0.3, 1.4),
				CFrame.new(sideX * 5, 2.75, sideZ * 7.75),
				HAZARD,
				Enum.Material.Metal,
				room
			)
		end
	end
	-- Ventanas rotas pintadas en los muros de la sala (cristal azulado) y franjas de peligro en las entradas.
	for _, sideX in { -1, 1 } do
		for _, z in { -10, 10 } do
			deco("MarcoVentana", Vector3.new(0.1, 3.4, 5.4), CFrame.new(sideX * 15.95, 6.5, z), CABLE, nil, room)
			deco("Ventana", Vector3.new(0.1, 3, 5), CFrame.new(sideX * 15.9, 6.5, z), GLASS, Enum.Material.Glass, room)
		end
		hazardStripe(room, Vector3.new(sideX * 15, 0.05, 0), 10, true)
	end
	for _, sideZ in { -1, 1 } do
		hazardStripe(room, Vector3.new(0, 0.05, sideZ * 15), 8, false)
	end
end

-- Los dos tapones del derrumbe: los colectores (|x| 44–56, z -30…-26) y el paso sur (|x| ≤ 4, z -28…-24).
local function buildCollapse(model: Model)
	local collapse = folder(model, "Derrumbes")
	for _, sideX in { -1, 1 } do
		-- Doce de ancho: cuatro losas de 3 sin huecos.
		LabParts.rubble(collapse, sideX * 44, -30, sideX * 56, -26, COLLAPSE_HEIGHT)
	end
	-- Ocho de ancho: dos tramos que se solapan (LabParts.rubble deja un hueco de 2 en los anchos de 8).
	LabParts.rubble(collapse, -4, -28, 2, -24, COLLAPSE_HEIGHT)
	LabParts.rubble(collapse, -2, -28, 4, -24, COLLAPSE_HEIGHT)
end

-- Foco enjaulado colgado del techo en (x, z), a "ceilingY" de alto: bloque de neón, jaula y luz.
local function lamp(parent: Instance, x: number, z: number, ceilingY: number)
	local bulb = deco(
		"Foco",
		Vector3.new(1.2, 0.9, 1.2),
		CFrame.new(x, ceilingY - 0.45, z),
		LAMP_COLOR,
		Enum.Material.Neon,
		parent
	)
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			deco(
				"Jaula",
				Vector3.new(0.15, 1.3, 0.15),
				CFrame.new(x + cx * 0.85, ceilingY - 0.65, z + cz * 0.85),
				STEEL_DARK,
				nil,
				parent
			)
		end
	end
	deco("Reja", Vector3.new(2, 0.15, 2), CFrame.new(x, ceilingY - 1.3, z), STEEL_DARK, nil, parent)
	local light = Instance.new("PointLight")
	light.Color = LAMP_COLOR
	light.Range = 32
	light.Brightness = 1.8
	light.Parent = bulb
end

-- Lo que cuelga del techo (todo decorado e inalcanzable): focos, tuberías que gotean suero, vigas, rejillas,
-- cables y raíces de la selva.
local function buildCeilingDecor(techo: Folder)
	local rng = LabParts.rng
	-- Focos: 18 PointLight (las zonas ponen cuatro más; el tope es 24).
	for _, sideX in { -1, 1 } do
		lamp(techo, sideX * 38, 0, CEILING)
		lamp(techo, sideX * 22, 0, CEILING)
		for _, sideZ in { -1, 1 } do
			lamp(techo, sideX * 11, sideZ * 11, PUMP_CEILING)
			lamp(techo, sideX * 50, sideZ * 22, CEILING)
			lamp(techo, sideX * 26, sideZ * 35, CEILING)
		end
	end
	lamp(techo, 0, 23, CEILING)
	lamp(techo, 0, -23, CEILING)

	-- Vigas del techo: de lado a lado de cada túnel.
	for x = 20, 42, 6 do
		for _, sideX in { -1, 1 } do
			deco(
				"Viga",
				Vector3.new(0.8, 0.8, 10),
				CFrame.new(sideX * x, CEILING - 0.4, 0),
				RUST_DARK,
				Enum.Material.CorrodedMetal,
				techo
			)
		end
	end
	for x = -40, 40, 8 do
		for _, sideZ in { -1, 1 } do
			deco(
				"Viga",
				Vector3.new(0.8, 0.8, 10),
				CFrame.new(x, CEILING - 0.4, sideZ * 35),
				RUST_DARK,
				Enum.Material.CorrodedMetal,
				techo
			)
		end
	end
	for z = -36, 36, 8 do
		for _, sideX in { -1, 1 } do
			deco(
				"Viga",
				Vector3.new(12, 0.8, 0.8),
				CFrame.new(sideX * 50, CEILING - 0.4, z),
				RUST_DARK,
				Enum.Material.CorrodedMetal,
				techo
			)
		end
	end

	-- Tuberías del techo, con juntas y goteras de suero (bloques pequeños de neón colgados de ellas).
	local function ceilingPipe(x: number, z: number, length: number, alongX: boolean)
		local size = if alongX then Vector3.new(length, 1.6, 1.6) else Vector3.new(1.6, 1.6, length)
		deco("TuberiaTecho", size, CFrame.new(x, CEILING - 0.8, z), STEEL, Enum.Material.Metal, techo)
		for offset = -length / 2 + 4, length / 2 - 3, 8 do
			local px = if alongX then x + offset else x
			local pz = if alongX then z else z + offset
			deco(
				"Junta",
				if alongX then Vector3.new(0.8, 1.9, 1.9) else Vector3.new(1.9, 1.9, 0.8),
				CFrame.new(px, CEILING - 0.8, pz),
				RUST,
				Enum.Material.CorrodedMetal,
				techo
			)
			if rng:NextNumber() < 0.7 then
				local drop = rng:NextNumber(1, 2.4)
				deco(
					"Gota",
					Vector3.new(0.3, drop, 0.3),
					CFrame.new(px + 0.4, CEILING - 1.6 - drop / 2, pz + 0.4),
					SERUM,
					Enum.Material.Neon,
					techo
				)
			end
		end
	end
	for _, sideX in { -1, 1 } do
		for _, sideZ in { -1, 1 } do
			ceilingPipe(sideX * 30, sideZ * 3.2, 26, true)
			ceilingPipe(sideX * 22, sideZ * 31.5, 44, true)
			ceilingPipe(sideX * 47, sideZ * 20, 40, false)
		end
		ceilingPipe(sideX * 22, 38.5, 44, true)
		ceilingPipe(sideX * 22, -38.5, 44, true)
		-- Los de la sala de bombas (techo a 20), a un lado de las lámparas.
		deco(
			"TuberiaSala",
			Vector3.new(1.6, 1.6, 28),
			CFrame.new(sideX * 13, PUMP_CEILING - 0.8, 0),
			STEEL,
			Enum.Material.Metal,
			techo
		)
		deco(
			"TuberiaSala",
			Vector3.new(28, 1.6, 1.6),
			CFrame.new(0, PUMP_CEILING - 0.8, sideX * 13),
			STEEL,
			Enum.Material.Metal,
			techo
		)
	end

	-- Rejillas de ventilación pegadas al techo.
	for _, spot in
		{
			{ 30, 0 },
			{ 50, 0 },
			{ 14, 35 },
			{ -14, -35 },
			{ 0, 23 },
			{ 0, -23 },
			{ 38, 35 },
			{ -38, 35 },
			{ 38, -35 },
			{ -38, -35 },
		}
	do
		deco("Rejilla", Vector3.new(3, 0.2, 3), CFrame.new(spot[1], CEILING - 0.1, spot[2]), STEEL_DARK, nil, techo)
		deco(
			"Brillo",
			Vector3.new(2.2, 0.1, 2.2),
			CFrame.new(spot[1], CEILING - 0.22, spot[2]),
			GLASS,
			Enum.Material.Glass,
			techo
		)
	end

	-- Cables que cuelgan entre las lámparas.
	for _, sideX in { -1, 1 } do
		cable(techo, Vector3.new(sideX * 38, CEILING - 0.2, 4), Vector3.new(sideX * 22, CEILING - 0.2, 4), 1.2)
		cable(techo, Vector3.new(sideX * 22, CEILING - 0.2, -4), Vector3.new(sideX * 38, CEILING - 0.2, -4), 1.2)
		cable(techo, Vector3.new(sideX * 26, CEILING - 0.2, 39), Vector3.new(sideX * 40, CEILING - 0.2, 39), 1.5)
		cable(techo, Vector3.new(sideX * 26, CEILING - 0.2, -39), Vector3.new(sideX * 40, CEILING - 0.2, -39), 1.5)
	end

	-- Raíces de la selva que entran por las grietas del techo, al azar por los túneles de techo bajo.
	for _ = 1, 40 do
		local rect = WALKABLE[rng:NextInteger(1, #WALKABLE)]
		if rect ~= WALKABLE[PUMP_INDEX] then
			local length = rng:NextNumber(2, 6)
			local x = rng:NextNumber(rect[1] + 1, rect[3] - 1)
			local z = rng:NextNumber(rect[2] + 1, rect[4] - 1)
			deco(
				"Raiz",
				Vector3.new(0.5, length, 0.5),
				CFrame.new(x, CEILING - length / 2, z),
				if rng:NextNumber() < 0.5 then WOOD_DARK else VINE_DARK,
				Enum.Material.Wood,
				techo
			)
		end
	end
end

-- Construye el mapa en coordenadas locales dentro de "model" (LabBuilder lo coloca después).
local function build(model: Model)
	buildShell(model)
	local techo = buildCeiling(model)
	buildWater(model)
	buildFaces(model)
	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	LabParts.buildZone(bases, "Pirates", -1, GEOMETRY)
	LabParts.buildZone(bases, "Guardians", 1, GEOMETRY)
	bases.Parent = model
	buildMainTunnel(model)
	buildSideTunnels(model)
	buildCollectors(model)
	buildPumpRoom(model, techo)
	buildCollapse(model)
	buildCeilingDecor(techo)
	LabParts.buildFreeSpawns(model, FREE_SPAWNS)
end

return {
	GEOMETRY = GEOMETRY,
	LIGHTING = LIGHTING,
	SEED = SEED,
	OVERHEAD_HEIGHT = OVERHEAD_HEIGHT,
	OVERHEAD_BACK = OVERHEAD_BACK,
	build = build,
}
