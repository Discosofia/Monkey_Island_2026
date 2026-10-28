--!strict
-- Piezas que comparten los mapas del Laboratorio en ruinas (Fase 13, docs/LABORATORIO.md §4): bloques y
-- decorado genéricos, coberturas (cajas, tanques de suero, jaulas, plataneras, cascotes), las zonas de salida
-- de cada bando (buildZone, con la geometría de cada mapa), los puntos libres, el horizonte de ciudad en
-- ruinas y la iluminación. Cada mapa (World/Maps/*) las junta; World/LabBuilder los construye todos.
--
-- Todo el decorado al azar (tonos, lianas, cascotes) sale de un solo Random con semilla (seed): el mismo
-- mapa en cada construcción mientras el orden de las llamadas no cambie.
--
-- Lo decorativo va con CanCollide, CanQuery y CanTouch en false; las barreras invisibles chocan con los
-- personajes pero los disparos las cruzan: van en el grupo Config.Lab.WallGroup, que no choca con el grupo
-- de los rayos del combate (Config.ShotCollisionGroup). CanQuery en false no basta: un rayo con los
-- parámetros por defecto sí golpea una pieza que choca.

local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LabMapModels = require(ReplicatedStorage.Shared.LabMapModels)

local PALETTE = LabMapModels.PALETTE
local CONCRETE = PALETTE.CONCRETE
local CONCRETE_DARK = PALETTE.CONCRETE_DARK
local RUST = PALETTE.RUST
local RUST_DARK = PALETTE.RUST_DARK
local STEEL = PALETTE.STEEL
local STEEL_DARK = PALETTE.STEEL_DARK
local GLASS = PALETTE.GLASS
local SERUM = PALETTE.SERUM
local CABLE = PALETTE.CABLE
local HAZARD = PALETTE.HAZARD
local VINE = PALETTE.VINE
local VINE_DARK = PALETTE.VINE_DARK
local LEAF = PALETTE.LEAF
local BANANA = PALETTE.BANANA
local WOOD = PALETTE.WOOD
local WOOD_DARK = PALETTE.WOOD_DARK
local LAB_WHITE = PALETTE.LAB_WHITE

-- Geometría de un mapa que usa buildZone (studs; el suelo está en y = 0, simétrico de oeste a este):
--   halfX / outerX     la boca y el fondo de las zonas de salida (|x|)
--   halfZ              la mitad del ancho de las zonas de salida
--   mouthFrom / mouthTo cada boca de la zona va de |z| mouthFrom a mouthTo
--   wallHeight         altura de los muros
--   ceiling            el techo invisible (y la altura del volumen "Zone")
--   gateHeight         altura de las barreras y las compuertas de las bocas
export type Geometry = {
	halfX: number,
	outerX: number,
	halfZ: number,
	mouthFrom: number,
	mouthTo: number,
	wallHeight: number,
	ceiling: number,
	gateHeight: number,
}

-- Iluminación de un mapa: applyLighting pone todas estas propiedades (la iluminación es global, así que
-- cada mapa tiene que dejar las suyas). Sin bloom, desenfoque o rayos de sol, esos efectos se apagan.
export type LightingPreset = {
	clockTime: number,
	latitude: number,
	brightness: number,
	exposure: number?,
	ambient: Color3,
	outdoorAmbient: Color3,
	atmosphere: {
		density: number,
		offset: number,
		color: Color3,
		decay: Color3,
		glare: number,
		haze: number,
	},
	colorCorrection: { brightness: number?, contrast: number, saturation: number, tint: Color3 },
	bloom: { intensity: number, size: number, threshold: number }?,
	depthOfField: { farIntensity: number, focusDistance: number, inFocusRadius: number, nearIntensity: number }?,
	sunRays: { intensity: number, spread: number }?,
}

-- Punto de aparición libre (Todos contra todos): x, z, la altura del suelo ("y", 0 si falta) y "closable" si
-- lo cubre el derrumbe de los formatos pequeños (no se usa mientras está cerrado).
export type FreeSpawnPoint = { x: number, z: number, y: number?, closable: boolean? }

-- Opciones del horizonte: sin ellas, el de la ciudad del Laboratorio central.
export type SkylineOptions = {
	towers: { { number } }?, -- { x, z, ancho, alto }
	baseY: number?, -- dónde se hunden las torres (−2)
	trees: number?, -- cuántas copas entre las torres (36)
	treeMinDistance: number?, -- (120)
	treeMaxDistance: number?, -- (280)
}

local WALL_THICKNESS = 2

local LabParts = {}

local rng = Random.new(0)
-- El mismo generador, para los mapas (Random no se puede reiniciar: seed lo cambia por uno nuevo).
LabParts.rng = rng

-- Empieza la serie del decorado al azar de un mapa.
function LabParts.seed(seed: number)
	rng = Random.new(seed)
	LabParts.rng = rng
end

-- Grupos de colisión: el del personaje de cada bando y el de las barreras de la zona de salida de cada
-- bando (que solo chocan con el personaje del otro).
function LabParts.characterGroup(teamId: string): string
	return `LabEquipo_{teamId}`
end

function LabParts.barrierGroup(teamId: string): string
	return `LabBarrera_{teamId}`
end

function LabParts.registerGroups()
	-- El grupo de los rayos del combate (lo registra también Combat/Hitbox al cargar) y el de los muros
	-- invisibles, que no choca con él. Con los personajes (Default y LabEquipo_*) el muro choca por defecto.
	for _, group in { Config.ShotCollisionGroup, Config.Lab.WallGroup } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(Config.Lab.WallGroup, Config.ShotCollisionGroup, false)
	for _, teamId in Config.Lab.TeamOrder do
		for _, group in { LabParts.characterGroup(teamId), LabParts.barrierGroup(teamId) } do
			if not PhysicsService:IsCollisionGroupRegistered(group) then
				PhysicsService:RegisterCollisionGroup(group)
			end
		end
	end
	for _, owner in Config.Lab.TeamOrder do
		for _, teamId in Config.Lab.TeamOrder do
			PhysicsService:CollisionGroupSetCollidable(
				LabParts.barrierGroup(owner),
				LabParts.characterGroup(teamId),
				teamId ~= owner
			)
		end
	end
end

function LabParts.block(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local block = LabParts.block

-- Bloque entre dos esquinas (x1, z1) y (x2, z2), de "height" de alto desde "bottom".
function LabParts.between(
	name: string,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	bottom: number,
	height: number,
	color: Color3,
	material: Enum.Material?,
	parent: Instance
): Part
	local size = Vector3.new(math.abs(x2 - x1), height, math.abs(z2 - z1))
	local center = Vector3.new((x1 + x2) / 2, bottom + height / 2, (z1 + z2) / 2)
	return block(name, size, CFrame.new(center), color, material, parent)
end

local between = LabParts.between

-- Pieza que no se ve ni choca ni la encuentran los rayos (marcas para el código).
function LabParts.marker(part: BasePart)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local marker = LabParts.marker

-- Decorado: se ve pero no choca ni lo encuentran los rayos. Las piezas pequeñas no dan sombra.
function LabParts.decor(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	if part.Size.Magnitude < 8 then
		part.CastShadow = false
	end
	return part
end

local decor = LabParts.decor

-- Adorno macizo: choca y lo encuentran los rayos. Para lo que sobresale de una cobertura o está al alcance
-- del jugador (zócalos, aros, tuberías del suelo): si se ve sólido, tiene que serlo.
function LabParts.solid(part: BasePart): BasePart
	part.CanTouch = false
	return part
end

local solid = LabParts.solid

-- Barrera invisible: choca con los personajes, pero los disparos y la puntería la cruzan (grupo
-- Config.Lab.WallGroup, ver registerGroups); sin CanQuery tampoco la encuentra la cámara.
function LabParts.barrier(
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	bottom: number,
	height: number,
	parent: Instance
)
	local part = between("Barrera", x1, z1, x2, z2, bottom, height, CONCRETE, nil, parent)
	part.Transparency = 1
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CollisionGroup = Config.Lab.WallGroup
end

local barrier = LabParts.barrier

-- Variación de tono para que el hormigón repetido no parezca de plástico.
function LabParts.tone(color: Color3, amount: number?): Color3
	return color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, amount or 0.1))
end

local tone = LabParts.tone

-- Pone la iluminación del mapa (todas las propiedades: la iluminación es global y el mapa anterior deja las
-- suyas) y apaga los efectos que el preset no trae.
function LabParts.applyLighting(preset: LightingPreset)
	Lighting.ClockTime = preset.clockTime
	Lighting.GeographicLatitude = preset.latitude
	Lighting.Brightness = preset.brightness
	Lighting.ExposureCompensation = preset.exposure or 0
	Lighting.Ambient = preset.ambient
	Lighting.OutdoorAmbient = preset.outdoorAmbient

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = preset.atmosphere.density
	atmosphere.Offset = preset.atmosphere.offset
	atmosphere.Color = preset.atmosphere.color
	atmosphere.Decay = preset.atmosphere.decay
	atmosphere.Glare = preset.atmosphere.glare
	atmosphere.Haze = preset.atmosphere.haze
	atmosphere.Parent = Lighting

	local grade = (Lighting:FindFirstChild("ColorLaboratorio") :: ColorCorrectionEffect?)
		or Instance.new("ColorCorrectionEffect")
	grade.Name = "ColorLaboratorio"
	grade.Parent = Lighting
	grade.Brightness = preset.colorCorrection.brightness or 0
	grade.Contrast = preset.colorCorrection.contrast
	grade.Saturation = preset.colorCorrection.saturation
	grade.TintColor = preset.colorCorrection.tint

	local bloom = Lighting:FindFirstChild("BloomLaboratorio") :: BloomEffect?
	if preset.bloom then
		bloom = bloom or Instance.new("BloomEffect")
		local effect = bloom :: BloomEffect
		effect.Name = "BloomLaboratorio"
		effect.Intensity = preset.bloom.intensity
		effect.Size = preset.bloom.size
		effect.Threshold = preset.bloom.threshold
		effect.Enabled = true
		effect.Parent = Lighting
	elseif bloom then
		bloom.Enabled = false
	end

	local depth = Lighting:FindFirstChild("DesenfoqueLaboratorio") :: DepthOfFieldEffect?
	if preset.depthOfField then
		depth = depth or Instance.new("DepthOfFieldEffect")
		local effect = depth :: DepthOfFieldEffect
		effect.Name = "DesenfoqueLaboratorio"
		effect.FarIntensity = preset.depthOfField.farIntensity
		effect.FocusDistance = preset.depthOfField.focusDistance
		effect.InFocusRadius = preset.depthOfField.inFocusRadius
		effect.NearIntensity = preset.depthOfField.nearIntensity
		effect.Enabled = true
		effect.Parent = Lighting
	elseif depth then
		depth.Enabled = false
	end

	local rays = Lighting:FindFirstChild("RayosLaboratorio") :: SunRaysEffect?
	if preset.sunRays then
		rays = rays or Instance.new("SunRaysEffect")
		local effect = rays :: SunRaysEffect
		effect.Name = "RayosLaboratorio"
		effect.Intensity = preset.sunRays.intensity
		effect.Spread = preset.sunRays.spread
		effect.Enabled = true
		effect.Parent = Lighting
	elseif rays then
		rays.Enabled = false
	end
end

-- Franjas de peligro (amarillo y negro) a lo largo de X, de "length" studs, en el suelo.
function LabParts.hazardStripe(parent: Instance, center: Vector3, length: number, alongZ: boolean)
	local count = math.floor(length / 2)
	for index = 0, count - 1 do
		local offset = (index - (count - 1) / 2) * 2
		local position = center + (if alongZ then Vector3.new(0, 0, offset) else Vector3.new(offset, 0, 0))
		local size = if alongZ then Vector3.new(1.5, 0.1, 2) else Vector3.new(2, 0.1, 1.5)
		decor(
			block(
				"Franja",
				size,
				CFrame.new(position),
				if index % 2 == 0 then HAZARD else CABLE,
				Enum.Material.SmoothPlastic,
				parent
			)
		)
	end
end

local hazardStripe = LabParts.hazardStripe

-- Cable que cuelga de "from" a "to", combado: tres tramos rectos.
function LabParts.cable(parent: Instance, from: Vector3, to: Vector3, sag: number)
	local middle = (from + to) / 2 - Vector3.new(0, sag, 0)
	local points = {
		from,
		(from + middle) / 2 - Vector3.new(0, sag * 0.25, 0),
		middle,
		(middle + to) / 2 - Vector3.new(0, sag * 0.25, 0),
		to,
	}
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		decor(
			block(
				"Cable",
				Vector3.new(0.3, 0.3, (b - a).Magnitude),
				CFrame.lookAt((a + b) / 2, b),
				CABLE,
				Enum.Material.SmoothPlastic,
				parent
			)
		)
	end
end

-- Liana que baja por una pared desde "top" (en la cara del muro que mira a "facing"): bloques de hojas
-- oscuras escalonados.
function LabParts.vine(parent: Instance, top: Vector3, facing: Vector3, length: number)
	local position = top
	for index = 1, math.floor(length / 1.5) do
		local wobble = rng:NextInteger(-1, 1) * 0.5
		local side = if math.abs(facing.X) > 0.5 then Vector3.new(0, 0, wobble) else Vector3.new(wobble, 0, 0)
		position = position - Vector3.new(0, 1.5, 0) + side
		decor(
			block(
				"Liana",
				Vector3.new(1.2, 1.5, 1.2) - Vector3.new(math.abs(facing.X), 0, math.abs(facing.Z)) * 0.8,
				CFrame.new(position + facing * 0.25),
				if index % 3 == 0 then VINE_DARK else VINE,
				Enum.Material.Grass,
				parent
			)
		)
	end
end

local vine = LabParts.vine

-- Muro de hormigón de "height" de alto entre dos esquinas, con un zócalo oscuro, una franja de cables
-- arriba y alguna liana.
function LabParts.wall(parent: Instance, x1: number, z1: number, x2: number, z2: number, height: number): Part
	local part = between("Muro", x1, z1, x2, z2, 0, height, tone(CONCRETE), Enum.Material.Concrete, parent)
	local sizeX, sizeZ = math.abs(x2 - x1), math.abs(z2 - z1)
	-- Zócalo y remate, un poco salidos.
	solid(
		between(
			"Zocalo",
			math.min(x1, x2) - 0.1,
			math.min(z1, z2) - 0.1,
			math.max(x1, x2) + 0.1,
			math.max(z1, z2) + 0.1,
			0,
			1.5,
			CONCRETE_DARK,
			Enum.Material.Concrete,
			parent
		)
	)
	decor(
		between(
			"Remate",
			math.min(x1, x2) - 0.15,
			math.min(z1, z2) - 0.15,
			math.max(x1, x2) + 0.15,
			math.max(z1, z2) + 0.15,
			height - 1,
			1,
			STEEL_DARK,
			Enum.Material.SmoothPlastic,
			parent
		)
	)
	-- Una liana por cada tramo largo, por los dos lados.
	local long = math.max(sizeX, sizeZ)
	for _ = 1, math.floor(long / 14) do
		local t = rng:NextNumber(0.15, 0.85)
		local center = part.Position
		if sizeX >= sizeZ then
			local x = math.min(x1, x2) + sizeX * t
			for _, facing in { Vector3.zAxis, -Vector3.zAxis } do
				local face = center.Z + facing.Z * sizeZ / 2
				vine(parent, Vector3.new(x, height, face), facing, rng:NextNumber(5, 12))
			end
		else
			local z = math.min(z1, z2) + sizeZ * t
			for _, facing in { Vector3.xAxis, -Vector3.xAxis } do
				local face = center.X + facing.X * sizeX / 2
				vine(parent, Vector3.new(face, height, z), facing, rng:NextNumber(5, 12))
			end
		end
	end
	return part
end

local wall = LabParts.wall

-- Caja de suministros (cobertura baja que para los disparos): metal con franja.
function LabParts.crate(parent: Instance, position: Vector3, size: number, color: Color3)
	block("Caja", Vector3.one * size, CFrame.new(position + Vector3.new(0, size / 2, 0)), color, nil, parent)
	decor(
		block(
			"Franja",
			Vector3.new(size + 0.1, 0.5, size + 0.1),
			CFrame.new(position + Vector3.new(0, size * 0.7, 0)),
			HAZARD,
			nil,
			parent
		)
	)
end

-- Cascotes que cierran un hueco entre (x1, z1) y (x2, z2) en los formatos pequeños (LabWorldService.setFormat):
-- losas de hormigón de la altura de los muros ("wallHeight") y hierros torcidos encima. Se construyen
-- cerrados; el servidor los abre según el formato.
function LabParts.rubble(parent: Instance, x1: number, z1: number, x2: number, z2: number, wallHeight: number)
	local sizeX, sizeZ = math.abs(x2 - x1), math.abs(z2 - z1)
	local alongX = sizeX >= sizeZ
	local length = math.max(sizeX, sizeZ)
	local center = Vector3.new((x1 + x2) / 2, 0, (z1 + z2) / 2)
	for offset = -length / 2 + 1.5, length / 2 - 1.5, 3 do
		local height = rng:NextNumber(wallHeight - 4, wallHeight)
		local slab =
			Vector3.new(if alongX then 3 else math.min(sizeX, 4), height, if alongX then math.min(sizeZ, 4) else 3)
		local position = center + (if alongX then Vector3.new(offset, 0, 0) else Vector3.new(0, 0, offset))
		block(
			"Cascote",
			slab,
			CFrame.new(position + Vector3.new(0, height / 2, 0)),
			tone(CONCRETE_DARK, 0.2),
			Enum.Material.Concrete,
			parent
		)
	end
	-- Hierros torcidos encima.
	for _ = 1, 2 do
		local position = center
			+ Vector3.new(rng:NextNumber(-1, 1) * sizeX / 3, wallHeight - 2, rng:NextNumber(-1, 1) * sizeZ / 3)
		block(
			"Hierro",
			Vector3.new(0.4, 5, 0.4),
			CFrame.new(position) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6)),
			RUST,
			Enum.Material.CorrodedMetal,
			parent
		)
	end
end

-- Tanque de suero roto (cobertura media): aro de metal, cristal azulado con huecos y el remate.
function LabParts.serumTank(parent: Instance, center: Vector3)
	local tank = Instance.new("Model")
	tank.Name = "Tanque"
	tank.Parent = parent
	block(
		"Basa",
		Vector3.new(6, 1, 6),
		CFrame.new(center + Vector3.new(0, 0.5, 0)),
		STEEL_DARK,
		Enum.Material.DiamondPlate,
		tank
	)
	-- El cristal en bloques de 1 × 1 por las cuatro caras, con algunos rotos (los de arriba, más).
	for level = 1, 3 do
		for _, face in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
			for offset = -1, 1 do -- las esquinas son de los montantes
				if rng:NextNumber() > 0.12 * level then
					local along = Vector3.new(face.Z, 0, face.X) * offset
					local pane = block(
						"Cristal",
						Vector3.new(1, 1, 1),
						CFrame.new(center + face * 2.5 + along + Vector3.new(0, level + 0.5, 0)),
						GLASS,
						Enum.Material.Glass,
						tank
					)
					pane.Transparency = 0.35
				end
			end
		end
	end
	-- Por dentro, un bloque macizo bajo (para que la cobertura pare de verdad) con el resto del suero.
	-- Más pequeño que el hueco de los cristales (±2): sin caras en el mismo plano, que parpadean.
	block("Dentro", Vector3.new(3.6, 3, 3.6), CFrame.new(center + Vector3.new(0, 2.5, 0)), CONCRETE_DARK, nil, tank)
	decor(
		block(
			"Suero",
			Vector3.new(3.4, 0.4, 3.4),
			CFrame.new(center + Vector3.new(0, 4.2, 0)),
			SERUM,
			Enum.Material.Neon,
			tank
		)
	)
	-- Montantes de las esquinas.
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			block(
				"Montante",
				Vector3.new(1.5, 4.5, 1.5),
				CFrame.new(center + Vector3.new(cx * 2.35, 3.25, cz * 2.35)),
				RUST,
				Enum.Material.CorrodedMetal,
				tank
			)
		end
	end
end

-- Jaula de barrotes de "size" × "size": chocan con los personajes, pero los disparos pasan entre ellos y por el techo
-- (grupo Config.Lab.WallGroup, además de CanQuery en false).
function LabParts.cage(parent: Instance, center: Vector3, size: number, broken: boolean)
	local model = Instance.new("Model")
	model.Name = if broken then "JaulaRota" else "Jaula"
	model.Parent = parent
	local height = 7
	local half = size / 2
	local function bar(position: Vector3, barHeight: number, tilt: number)
		local part = block(
			"Barrote",
			Vector3.new(0.4, barHeight, 0.4),
			CFrame.new(position + Vector3.new(0, barHeight / 2, 0)) * CFrame.Angles(tilt, 0, 0),
			STEEL,
			Enum.Material.Metal,
			model
		)
		part.CanQuery = false
		part.CollisionGroup = Config.Lab.WallGroup
	end
	for offset = -half, half, 1.5 do
		for _, sideZ in { -1, 1 } do
			local bent = broken and sideZ == 1 and math.abs(offset) < 2
			bar(center + Vector3.new(offset, 0, sideZ * half), if bent then 3 else height, if bent then 0.5 else 0)
		end
		for _, sideX in { -1, 1 } do
			bar(center + Vector3.new(sideX * half, 0, offset), height, 0)
		end
	end
	-- Techo y suelo de la jaula.
	local roof = block(
		"TechoJaula",
		Vector3.new(size + 0.6, 0.6, size + 0.6),
		CFrame.new(center + Vector3.new(0, height + 0.3, 0)),
		RUST_DARK,
		Enum.Material.CorrodedMetal,
		model
	)
	roof.CanQuery = false
	roof.CollisionGroup = Config.Lab.WallGroup
	decor(
		block(
			"SueloJaula",
			Vector3.new(size, 0.15, size),
			CFrame.new(center + Vector3.new(0, 0.08, 0)),
			STEEL_DARK,
			Enum.Material.DiamondPlate,
			model
		)
	)
end

-- Platanera primal (decorado: tapa la vista pero no para nada): tronco, hojas grandes y un racimo.
function LabParts.bananaPlant(parent: Instance, ground: Vector3, height: number)
	decor(
		block(
			"Tronco",
			Vector3.new(1, height, 1),
			CFrame.new(ground + Vector3.new(0, height / 2, 0)),
			Color3.fromRGB(96, 104, 62),
			Enum.Material.Grass,
			parent
		)
	)
	for index = 1, 4 do
		local angle = index * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		decor(
			block(
				"Hoja",
				Vector3.new(2.4, 0.3, 5),
				CFrame.lookAt(
					ground + Vector3.new(0, height - 0.4, 0) + out * 2.4,
					ground + Vector3.new(0, height - 1.6, 0) + out * 5
				),
				if index % 2 == 0 then LEAF else VINE,
				Enum.Material.Grass,
				parent
			)
		)
	end
	decor(
		block(
			"Racimo",
			Vector3.new(1.2, 1.6, 1.2),
			CFrame.new(ground + Vector3.new(0.7, height - 1.5, 0)),
			BANANA,
			nil,
			parent
		)
	)
end

-- Zona de salida de "teamId" ("side" -1 oeste, 1 este): suelo, paredes, las dos bocas con su barrera y
-- su compuerta, la baldosa de aparición y el volumen de la zona, con las medidas de "geo". El dintel sobre
-- las bocas solo se pone si los muros son más altos que las compuertas.
function LabParts.buildZone(bases: Folder, teamId: string, side: number, geo: Geometry)
	local team = Config.Lab.Teams[teamId]
	local model = Instance.new("Model")
	model.Name = teamId
	model.Parent = bases
	local inner, outer = side * geo.halfX, side * geo.outerX
	local pirate = teamId == "Pirates"
	local halfZ, mouthFrom, mouthTo = geo.halfZ, geo.mouthFrom, geo.mouthTo

	-- Suelo: tablones del muelle o el hormigón blanco de la esclusa.
	if pirate then
		for z = -halfZ, halfZ - 2, 2 do
			local plank = between(
				"Tablon",
				inner,
				z,
				outer,
				z + 2,
				-1,
				1,
				if (z / 2) % 2 == 0 then WOOD else tone(WOOD, 0.15),
				Enum.Material.WoodPlanks,
				model
			)
			plank.Locked = true
		end
	else
		between("SueloEsclusa", inner, -halfZ, outer, halfZ, -1, 1, LAB_WHITE, Enum.Material.Concrete, model)
		hazardStripe(model, Vector3.new((inner + outer) / 2, 0.05, halfZ - 2), math.abs(outer - inner) - 2, false)
		hazardStripe(model, Vector3.new((inner + outer) / 2, 0.05, -halfZ + 2), math.abs(outer - inner) - 2, false)
	end

	-- Paredes de los lados (norte y sur) y la de la boca, con dos huecos.
	local sideColor = if pirate then WOOD_DARK else LAB_WHITE
	for _, sideZ in { -1, 1 } do
		local part = between(
			"Pared",
			inner,
			sideZ * halfZ,
			outer + side * WALL_THICKNESS,
			sideZ * (halfZ + WALL_THICKNESS),
			0,
			geo.wallHeight,
			sideColor,
			if pirate then Enum.Material.WoodPlanks else Enum.Material.Concrete,
			model
		)
		part.Name = "Pared"
		-- Franja del bando a media altura.
		decor(
			between("FranjaBando", inner, sideZ * (halfZ - 0.1), outer, sideZ * halfZ, 6, 1.5, team.color, nil, model)
		)
	end
	local mouthX1, mouthX2 = inner, inner + side * WALL_THICKNESS
	for _, range in { { -halfZ, -mouthTo }, { -mouthFrom, mouthFrom }, { mouthTo, halfZ } } do
		wall(model, mouthX1, range[1], mouthX2, range[2], geo.wallHeight)
	end
	for _, sideZ in { -1, 1 } do
		-- Dintel sobre cada boca (la barrera no llega hasta arriba).
		if geo.wallHeight > geo.gateHeight then
			between(
				"Dintel",
				mouthX1,
				sideZ * mouthFrom,
				mouthX2,
				sideZ * mouthTo,
				geo.gateHeight,
				geo.wallHeight - geo.gateHeight,
				CONCRETE_DARK,
				Enum.Material.Concrete,
				model
			)
		end
		-- La barrera del bando: solo choca con el rival (registerGroups). Un campo a franjas del color del
		-- bando que los disparos cruzan (y que en la zona no hacen daño, LabCombatRules).
		local field = between(
			"Barrier",
			(mouthX1 + mouthX2) / 2 - 0.3,
			sideZ * mouthFrom,
			(mouthX1 + mouthX2) / 2 + 0.3,
			sideZ * mouthTo,
			0,
			geo.gateHeight,
			team.color,
			Enum.Material.ForceField,
			model
		)
		field.Transparency = 0.45
		field.CanQuery = false
		field.CanTouch = false
		field.CastShadow = false
		field.CollisionGroup = LabParts.barrierGroup(teamId)
		-- La compuerta de antes de la partida: una persiana de metal, del lado de dentro.
		local gate = between(
			"Gate",
			mouthX2 + side * 0.5,
			sideZ * mouthFrom,
			mouthX2 + side * 1.5,
			sideZ * mouthTo,
			0,
			geo.gateHeight,
			STEEL,
			Enum.Material.DiamondPlate,
			model
		)
		gate.Transparency = 0.35
		gate.CanQuery = false
		gate.CanTouch = false
		hazardStripe(
			model,
			Vector3.new(inner + side * 3, 0.05, sideZ * (mouthFrom + mouthTo) / 2),
			mouthTo - mouthFrom,
			true
		)
	end

	-- Baldosa de aparición y volumen de la zona.
	local spawn = block(
		"Spawn",
		Vector3.new(8, 0.2, 8),
		CFrame.new((inner + outer) / 2, 0.1, 0),
		team.color,
		Enum.Material.SmoothPlastic, -- sin brillo: en primera persona se ve de cerca
		model
	)
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	local zone = between("Zone", inner, -halfZ, outer, halfZ, 0, geo.ceiling, CONCRETE, nil, model)
	marker(zone)

	-- El fondo de la zona.
	if pirate then
		-- El muelle se acaba en el agua: barrera invisible y postes.
		barrier(outer + side * WALL_THICKNESS, -halfZ, outer, halfZ, 0, geo.ceiling, model)
		for z = -halfZ + 2, halfZ - 2, 6 do
			block(
				"Poste",
				Vector3.new(1, 4, 1),
				CFrame.new(outer - side * 0.5, 1, z),
				WOOD_DARK,
				Enum.Material.Wood,
				model
			)
			decor(
				block(
					"Cuerda",
					Vector3.new(0.3, 0.3, 6),
					CFrame.new(outer - side * 0.5, 2.6, z + 3),
					Color3.fromRGB(190, 160, 110),
					nil,
					model
				)
			)
		end
		-- Barriles y cajas dentro de la zona (cobertura para salir).
		for _, spot in { Vector3.new(outer - side * 3, 0, 12), Vector3.new(outer - side * 3, 0, -12) } do
			block(
				"Barril",
				Vector3.new(3, 3.5, 3),
				CFrame.new(spot + Vector3.new(0, 1.75, 0)),
				WOOD,
				Enum.Material.Wood,
				model
			)
			solid(
				block(
					"Aro",
					Vector3.new(3.2, 0.4, 3.2),
					CFrame.new(spot + Vector3.new(0, 2.6, 0)),
					team.color,
					Enum.Material.Metal,
					model
				)
			)
		end
		-- Farolillos dorados en las paredes.
		for _, sideZ in { -1, 1 } do
			for _, t in { 0.3, 0.7 } do
				local x = inner + (outer - inner) * t
				local lamp = block(
					"Farol",
					Vector3.new(1, 1.4, 1),
					CFrame.new(x, 8, sideZ * (halfZ - 0.7)),
					team.color,
					Enum.Material.Neon,
					model
				)
				decor(lamp)
				local light = Instance.new("PointLight")
				light.Color = team.color
				light.Range = 14
				light.Brightness = 1.2
				light.Parent = lamp
			end
		end
	else
		-- La compuerta blindada al fondo, medio abierta (decorado: detrás hay hormigón).
		between(
			"Fondo",
			outer,
			-halfZ - WALL_THICKNESS,
			outer + side * WALL_THICKNESS,
			halfZ + WALL_THICKNESS,
			0,
			geo.wallHeight,
			LAB_WHITE,
			Enum.Material.Concrete,
			model
		)
		local doorX = outer - side * 0.3
		decor(
			block(
				"Compuerta",
				Vector3.new(0.6, 10, 12),
				CFrame.new(doorX, 7, 0),
				STEEL,
				Enum.Material.DiamondPlate,
				model
			)
		)
		decor(block("Rendija", Vector3.new(0.7, 2, 12), CFrame.new(doorX, 1, 0), CABLE, nil, model))
		decor(block("MarcoCompuerta", Vector3.new(0.8, 1, 14), CFrame.new(doorX, 12.5, 0), team.color, nil, model))
		for _, sideZ in { -1, 1 } do
			decor(
				block(
					"MarcoCompuerta",
					Vector3.new(0.8, 13, 1),
					CFrame.new(doorX, 6.5, sideZ * 6.5),
					team.color,
					nil,
					model
				)
			)
			-- Focos en lo alto.
			local spot = block(
				"Foco",
				Vector3.new(1.5, 1, 1.5),
				CFrame.new(outer - side * 1, 14, sideZ * 10),
				LAB_WHITE,
				Enum.Material.Neon,
				model
			)
			decor(spot)
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Bottom
			light.Range = 22
			light.Angle = 70
			light.Brightness = 2
			light.Color = Color3.fromRGB(220, 235, 255)
			light.Parent = spot
		end
		-- Taquillas de seguridad (cobertura para salir).
		for _, sideZ in { -1, 1 } do
			block(
				"Taquilla",
				Vector3.new(3, 5, 3),
				CFrame.new(outer - side * 3, 2.5, sideZ * 12),
				LAB_WHITE,
				nil,
				model
			)
			solid(
				block(
					"FranjaTaquilla",
					Vector3.new(3.1, 0.6, 3.1),
					CFrame.new(outer - side * 3, 3.8, sideZ * 12),
					team.color,
					nil,
					model
				)
			)
		end
	end
end

-- Marcadores donde aparece cada uno en Todos contra todos (LabWorldService.freeSpawnCFrame): invisibles y
-- sin choque, en la altura de su suelo (y) y con el atributo Closable si los cubre el derrumbe. Cada mapa
-- trae los suyos.
function LabParts.buildFreeSpawns(folder: Instance, points: { FreeSpawnPoint })
	local spawns = Instance.new("Folder")
	spawns.Name = "SpawnsLibres"
	spawns.Parent = folder
	for _, point in points do
		local part = block(
			"Libre",
			Vector3.new(4, 0.2, 4),
			CFrame.new(point.x, (point.y or 0) + 0.1, point.z),
			CONCRETE,
			nil,
			spawns
		)
		marker(part)
		if point.closable then
			part:SetAttribute("Closable", true)
		end
	end
end

-- Avisa si un marcador de SpawnsLibres tiene algo que choque donde estaría el personaje (se llama con el
-- mapa ya en Workspace; los rayos solo encuentran lo que tiene CanQuery, que es lo que importa: muros,
-- coberturas, bancales).
function LabParts.checkFreeSpawns(folder: Instance)
	local spawns = folder:FindFirstChild("SpawnsLibres")
	if not spawns then
		return
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { spawns }
	for _, part in spawns:GetChildren() do
		if part:IsA("BasePart") then
			-- Del pecho a la cabeza (el suelo queda por debajo) y con 2 studs de reparto a cada lado.
			local box = CFrame.new(part.Position + Vector3.new(0, 2.9, 0))
			for _, hit in Workspace:GetPartBoundsInBox(box, Vector3.new(6, 4, 6), params) do
				if hit.CanCollide then
					warn(`[LabBuilder] El punto libre {part.Position} choca con {hit:GetFullName()}`)
				end
			end
		end
	end
end

-- Rascacielos en ruinas comidos por la selva alrededor (decorado, lejos): torres de hormigón con
-- ventanas a franjas, algo inclinadas, con copas de árboles oscuras encima y lianas. Sin "options", el
-- horizonte del Laboratorio central.
function LabParts.buildSkyline(folder: Instance, options: SkylineOptions?)
	local skyline = Instance.new("Folder")
	skyline.Name = "CiudadPerdida"
	skyline.Parent = folder
	local towers = (options and options.towers)
		or {
			{ 0, 190, 50, 170 },
			{ 150, 170, 44, 140 },
			{ -170, 150, 48, 190 },
			{ 210, -40, 40, 120 },
			{ 140, -180, 52, 200 },
			{ -40, -200, 46, 150 },
			{ -200, -150, 40, 130 },
			{ 260, 90, 38, 110 },
		}
	local baseY = (options and options.baseY) or -2
	for index, tower in towers do
		local x, z, width, height = tower[1], tower[2], tower[3], tower[4]
		local lean = CFrame.Angles(rng:NextNumber(-0.05, 0.05), rng:NextNumber(0, math.pi), rng:NextNumber(-0.05, 0.05))
		local base = CFrame.new(x, baseY, z) * lean
		decor(
			block(
				"Torre",
				Vector3.new(width, height, width),
				base * CFrame.new(0, height / 2, 0),
				tone(CONCRETE, 0.25),
				Enum.Material.Concrete,
				skyline
			)
		)
		-- Ventanas: una franja oscura cada 8 studs.
		for y = 10, height - 8, 8 do
			decor(
				block(
					"Ventanas",
					Vector3.new(width + 0.4, 3, width + 0.4),
					base * CFrame.new(0, y, 0),
					STEEL_DARK,
					Enum.Material.Glass,
					skyline
				)
			)
		end
		-- La selva por encima y bajando por una cara.
		for _ = 1, 3 do
			local offset = Vector3.new(
				rng:NextNumber(-0.3, 0.3) * width,
				height + rng:NextNumber(0, 6),
				rng:NextNumber(-0.3, 0.3) * width
			)
			decor(
				block(
					"Copa",
					Vector3.new(16, 8, 16),
					base * CFrame.new(offset),
					if index % 2 == 0 then VINE else VINE_DARK,
					Enum.Material.Grass,
					skyline
				)
			)
		end
		decor(
			block(
				"Enredadera",
				Vector3.new(width * 0.4, height * 0.6, 1),
				base * CFrame.new(0, height * 0.55, width / 2 + 0.5),
				VINE_DARK,
				Enum.Material.Grass,
				skyline
			)
		)
	end
	-- Copas de la selva entre las torres.
	local minDistance = (options and options.treeMinDistance) or 120
	local maxDistance = (options and options.treeMaxDistance) or 280
	for _ = 1, (options and options.trees) or 36 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(minDistance, maxDistance)
		local size = rng:NextNumber(14, 26)
		local ground = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		-- Tronco hasta la copa, que es un bloque ancho y bajo.
		decor(
			block(
				"Tronco",
				Vector3.new(2, size, 2),
				CFrame.new(ground + Vector3.new(0, size / 2, 0)),
				WOOD_DARK,
				Enum.Material.Wood,
				skyline
			)
		)
		decor(
			block(
				"Arbol",
				Vector3.new(size, size * 0.5, size),
				CFrame.new(ground + Vector3.new(0, size, 0)),
				if rng:NextNumber() < 0.5 then VINE else VINE_DARK,
				Enum.Material.Grass,
				skyline
			)
		)
	end
end

return LabParts
