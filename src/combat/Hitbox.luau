--!strict
-- Detección de impactos (Fase 10, C3): un solo módulo para saber a quién alcanza un golpe, un disparo
-- o un área. Nunca .Touched: siempre una consulta del servidor en el instante del impacto.
--   - ray / visible: línea de visión. Solo la tapan las piezas que chocan (CanCollide) y el terreno;
--     no el agua ni los combatientes (un mono no esconde a otro). Un área solo alcanza a quien se ve
--     desde su centro: las paredes, rocas y coberturas protegen.
--   - inSphere: los combatientes cuya raíz está a menos de un radio (como antes, para no cambiar los
--     números de la calculadora), con línea de visión.
--   - inBox: los combatientes con alguna pieza dentro de una caja (GetPartBoundsInBox), con línea de
--     visión. Es el golpe con arma; la cadena de C4 lo barrerá con sweepBox.
--   - sweepSphere / sweepBox: Spherecast y Blockcast (disparos y barridos); devuelven lo primero que tocan.
--   - sweepCombatants: una esfera que avanza solo entre los combatientes (cada paso de un proyectil, C9;
--     el mundo lo mira ray: así el decorado que no choca no para los disparos). Dice también la zona de la
--     pieza que toca (zoneOf), sin rebobinar la pose.
--   - sweepBodies (Fase 15, V7; por piezas en la Fase 19, W6): un punto que avanza solo entre los jugadores
--     vivos. La cápsula del cuerpo y la esfera de la cabeza (Config.Combat.Headshot) en la posición
--     rebobinada por el lag del tirador sirven de filtro barato; si aciertan, se prueba pieza a pieza con la
--     pose de entonces (Combat/PositionHistory.poseInto). Dice cuál es el primero y la zona que toca.
--   - zoneOf: la zona de daño de una pieza ("Head", "Torso", "Limb" o "Weak"; Shared/Zones).
--   - rewound: dónde estaba un combatiente hace unos segundos (Combat/PositionHistory), para el lag.
-- Combatientes: los modelos con la etiqueta Config.Combat.EnemyTag (monos, jefes, muñecos) y los
-- personajes de los jugadores. La lista se rehace solo cuando cambia, y las consultas de piezas buscan
-- solo entre ellos (lista de inclusión), no en todo el mapa.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PositionHistory = require(script.Parent.PositionHistory)

local ENEMY_TAG = Config.Combat.EnemyTag
local HEADSHOT = Config.Combat.Headshot
local ZONES = Config.Combat.Zones
-- Si cabeza y cuerpo se tocan a distancias que difieren menos de esto (studs), cuenta la cabeza.
local HEAD_TIE_STUDS = 0.05

-- Zona de daño de una pieza (Fase 19, W6; Hitbox.zoneOf).
export type Zone = "Head" | "Torso" | "Limb" | "Weak"

export type Query = {
	exclude: Model?, -- quien ataca: nunca se alcanza a sí mismo
	from: Vector3?, -- desde dónde se mira la línea de visión (por defecto, el centro de la consulta)
	throughWalls: boolean?, -- sin línea de visión (quien llama ya ha mirado el camino)
	rewind: number?, -- segundos: también vale dónde estaba entonces (lag del atacante, con tope)
	flatHeight: number?, -- inSphere en horizontal, con este margen arriba y abajo (lo que está en el suelo)
}

local NO_QUERY: Query = {}

local Hitbox = {}

local combatants: { Model } = {}
local isCombatant: { [Model]: boolean } = {}
local dirty = true
local started = false

-- Los rayos del mundo (línea de visión, barridos) van en su propio grupo de colisión: una pieza con
-- CanQuery en false pero que choca (los muros invisibles del Laboratorio) los frenaría igual, así que
-- esas piezas van en un grupo que no choca con este (LabParts.registerGroups). Un grupo nuevo choca con
-- todo por defecto: sin esos muros, en la Isla, Dunas y el Lobby, se comporta como Default.
local SHOT_GROUP = Config.ShotCollisionGroup
local okGroup = pcall(function()
	if not PhysicsService:IsCollisionGroupRegistered(SHOT_GROUP) then
		PhysicsService:RegisterCollisionGroup(SHOT_GROUP)
	end
end)

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
sightParams.IgnoreWater = true
sightParams.RespectCanCollide = true
if okGroup then
	sightParams.CollisionGroup = SHOT_GROUP
end

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local combatantCastParams = RaycastParams.new()
combatantCastParams.FilterType = Enum.RaycastFilterType.Include

local function rebuild()
	table.clear(combatants)
	table.clear(isCombatant)
	for _, instance in CollectionService:GetTagged(ENEMY_TAG) do
		if instance:IsA("Model") then
			table.insert(combatants, instance)
			isCombatant[instance] = true
		end
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and not isCombatant[character] then
			table.insert(combatants, character)
			isCombatant[character] = true
		end
	end
	sightParams.FilterDescendantsInstances = combatants
	overlapParams.FilterDescendantsInstances = combatants
	combatantCastParams.FilterDescendantsInstances = combatants
	dirty = not started
end

-- Monos, jefes, muñecos y personajes (no copiar ni cambiar la lista).
function Hitbox.combatants(): { Model }
	if dirty then
		rebuild()
	end
	return combatants
end

-- La raíz de un combatiente: HumanoidRootPart o, si no tiene, su PrimaryPart.
function Hitbox.rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end
local rootOf = Hitbox.rootOf

-- El combatiente al que pertenece "part", o nil.
function Hitbox.ownerOf(part: Instance): Model?
	Hitbox.combatants()
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if isCombatant[model] then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Rayo contra el mundo (terreno y piezas que chocan), sin combatientes ni agua.
function Hitbox.ray(origin: Vector3, direction: Vector3): RaycastResult?
	Hitbox.combatants()
	return Workspace:Raycast(origin, direction, sightParams)
end

-- true si desde "from" se ve la raíz (o la cabeza) de "model" sin pared en medio.
function Hitbox.visible(from: Vector3, model: Model): boolean
	local root = rootOf(model)
	if not root then
		return false
	end
	if not Hitbox.ray(from, root.Position - from) then
		return true
	end
	-- Medio escondido tras algo bajo: con la cabeza a la vista también cuenta.
	local head = model:FindFirstChild("Head")
	return head ~= nil and head:IsA("BasePart") and not Hitbox.ray(from, head.Position - from)
end

-- Dónde estaba la raíz de "model" hace "seconds" (la actual si no hay historia).
function Hitbox.rewound(model: Model, seconds: number): Vector3?
	local past = if seconds > 0 then PositionHistory.at(model, seconds) else nil
	if past then
		return past
	end
	local root = rootOf(model)
	return if root then root.Position else nil
end

-- La forma de un personaje (Fase 15, V7): la cápsula del cuerpo (de los pies "feet" al cuello "neck", ambos
-- en la vertical de la raíz) y la esfera de la cabeza (centro y radio ya ensanchado), con sus piezas
-- actuales. "root" es la raíz; la cabeza puede faltar.
type BodyShape = {
	root: BasePart,
	feet: Vector3,
	neck: Vector3,
	headCenter: Vector3?,
	headRadius: number,
}

local function bodyShape(model: Model): BodyShape?
	local root = rootOf(model)
	if not root then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	local rootPosition = root.Position
	local feetY = rootPosition.Y - ((if humanoid then humanoid.HipHeight else 0) + root.Size.Y / 2)
	local headCenter: Vector3? = nil
	local headRadius = 0
	local neckY = rootPosition.Y + root.Size.Y / 2
	if head and head:IsA("BasePart") then
		headCenter = head.Position
		-- El radio visible de la pieza (la mitad de su lado mayor) sirve igual en R6, R15 y escalado.
		headRadius = math.max(head.Size.X, head.Size.Y, head.Size.Z) / 2 * HEADSHOT.HeadRadiusScale
		neckY = head.Position.Y - headRadius
	end
	neckY = math.max(neckY, feetY)
	return {
		root = root,
		feet = Vector3.new(rootPosition.X, feetY, rootPosition.Z),
		neck = Vector3.new(rootPosition.X, neckY, rootPosition.Z),
		headCenter = headCenter,
		headRadius = headRadius,
	}
end

-- Distancia a lo largo del segmento (origen "o", unitario "u", largo "length") hasta que entra en la
-- esfera de centro "c" y radio "r", o nil. Si ya empieza dentro, 0.
local function segmentSphere(o: Vector3, u: Vector3, length: number, c: Vector3, r: number): number?
	local m = o - c
	local b = m:Dot(u)
	local k = m:Dot(m) - r * r
	if k <= 0 then
		return 0
	end
	if b > 0 then
		return nil
	end
	local disc = b * b - k
	if disc < 0 then
		return nil
	end
	local t = -b - math.sqrt(disc)
	return if t <= length then math.max(t, 0) else nil
end

-- Lo mismo contra una cápsula vertical de "a" (abajo) a "b" (arriba) y radio "r": el cilindro entre los
-- dos puntos más las esferas de los extremos.
local function segmentCapsule(o: Vector3, u: Vector3, length: number, a: Vector3, b: Vector3, r: number): number?
	local best = segmentSphere(o, u, length, a, r)
	local top = segmentSphere(o, u, length, b, r)
	if top and (not best or top < best) then
		best = top
	end
	local axis = b - a
	local axisLength = axis.Magnitude
	if axisLength < 1e-3 then
		return best
	end
	local v = axis / axisLength
	local m = o - a
	local perpendicular = m - v * m:Dot(v)
	local travel = u - v * u:Dot(v)
	local qa = travel:Dot(travel)
	local qb = perpendicular:Dot(travel)
	local qc = perpendicular:Dot(perpendicular) - r * r
	local t: number? = nil
	if qc <= 0 then
		-- Dentro del cilindro infinito: vale si está entre los extremos.
		local along = m:Dot(v)
		if along >= 0 and along <= axisLength then
			t = 0
		end
	elseif qa > 1e-9 then
		local disc = qb * qb - qa * qc
		if disc >= 0 then
			local hit = (-qb - math.sqrt(disc)) / qa
			if hit >= 0 and hit <= length then
				local along = (o + u * hit - a):Dot(v)
				if along >= 0 and along <= axisLength then
					t = hit
				end
			end
		end
	end
	if t and (not best or t < best) then
		best = t
	end
	return best
end

local function sees(query: Query, center: Vector3, model: Model): boolean
	return query.throughWalls == true or Hitbox.visible(query.from or center, model)
end

-- Combatientes con la raíz a menos de "radius" de "center" (ver Query).
function Hitbox.inSphere(center: Vector3, radius: number, query: Query?): { Model }
	local options = query or NO_QUERY
	local flatHeight = options.flatHeight
	local rewind = options.rewind or 0
	local function inside(position: Vector3): boolean
		local offset = position - center
		if flatHeight then
			return Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius and math.abs(offset.Y) <= flatHeight
		end
		return offset.Magnitude <= radius
	end
	local found: { Model } = {}
	for _, model in Hitbox.combatants() do
		local root = rootOf(model)
		if model ~= options.exclude and root and root.Parent then
			local past = if rewind > 0 then PositionHistory.at(model, rewind) else nil
			if (inside(root.Position) or (past ~= nil and inside(past))) and sees(options, center, model) then
				table.insert(found, model)
			end
		end
	end
	return found
end

-- Combatientes con alguna pieza dentro de la caja (o, con "rewind", con algún punto de su cápsula del
-- cuerpo dentro donde estaban entonces, con el radio de la cápsula de margen). Ver Query.
function Hitbox.inBox(cframe: CFrame, size: Vector3, query: Query?): { Model }
	local options = query or NO_QUERY
	local center = cframe.Position
	local found: { Model } = {}
	local seen: { [Model]: boolean } = {}
	local function consider(model: Model)
		seen[model] = true
		if model ~= options.exclude and sees(options, center, model) then
			table.insert(found, model)
		end
	end
	Hitbox.combatants()
	for _, part in Workspace:GetPartBoundsInBox(cframe, size, overlapParams) do
		local model = Hitbox.ownerOf(part)
		if model and not seen[model] then
			consider(model)
		end
	end
	local rewind = options.rewind or 0
	if rewind > 0 then
		-- La caja se ensancha el radio de la cápsula del cuerpo; se prueban sus pies, su centro y su cuello
		-- trasladados a donde estaba entonces (solo coherencia con los disparos: sin cabeza).
		local half = size / 2 + Vector3.one * HEADSHOT.BodyRadius
		for _, model in combatants do
			local past = if seen[model] or not model.Parent then nil else PositionHistory.at(model, rewind)
			local shape = if past then bodyShape(model) else nil
			if past and shape then
				local shift = past - shape.root.Position
				local feet = shape.feet + shift
				local neck = shape.neck + shift
				for _, point in { feet, feet:Lerp(neck, 0.5), neck } do
					local localPoint = cframe:PointToObjectSpace(point)
					if
						math.abs(localPoint.X) <= half.X
						and math.abs(localPoint.Y) <= half.Y
						and math.abs(localPoint.Z) <= half.Z
					then
						consider(model)
						break
					end
				end
			end
		end
	end
	return found
end

local function castParams(ignore: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	if okGroup then
		params.CollisionGroup = SHOT_GROUP
	end
	return params
end

-- Esfera de "radius" que avanza "displacement" desde "origin": lo primero que toca (combatiente o
-- mundo), sin lo de "ignore". No ve lo que ya toca al salir.
function Hitbox.sweepSphere(
	origin: Vector3,
	radius: number,
	displacement: Vector3,
	ignore: { Instance }
): RaycastResult?
	return Workspace:Spherecast(origin, radius, displacement, castParams(ignore))
end

-- Caja de "size" en "cframe" que avanza "displacement": lo primero que toca, sin lo de "ignore".
function Hitbox.sweepBox(cframe: CFrame, size: Vector3, displacement: Vector3, ignore: { Instance }): RaycastResult?
	return Workspace:Blockcast(cframe, size, displacement, castParams(ignore))
end

-- Esfera de "radius" que avanza "displacement" desde "origin" solo entre los combatientes: el primero
-- que toca que no esté en "skip" (quien dispara, los ya atravesados), la distancia que ha avanzado su
-- centro y el punto de contacto. No ve lo que ya toca al salir: quien llama sale desde un poco antes.
-- Con "skipPlayers", tampoco ve a los personajes de jugadores (los prueba sweepBodies). El cuarto valor es la
-- zona de la pieza que toca (Hitbox.zoneOf) con la pose actual, sin rebobinar.
function Hitbox.sweepCombatants(
	origin: Vector3,
	radius: number,
	displacement: Vector3,
	skip: { [Model]: boolean },
	skipPlayers: boolean?
): (Model?, number, Vector3?, Zone?)
	Hitbox.combatants()
	local length = displacement.Magnitude
	if length < 1e-3 then
		return nil, 0, nil, nil
	end
	local direction = displacement / length
	local travelled = 0
	-- Si toca a uno de "skip", sigue desde ahí (ya lo toca, así que no lo vuelve a ver); unas pocas veces.
	for _ = 1, 6 do
		local result = Workspace:Spherecast(
			origin + direction * travelled,
			radius,
			direction * (length - travelled),
			combatantCastParams
		)
		if not result then
			return nil, length, nil, nil
		end
		travelled += math.max(result.Distance, 0.05)
		local model = Hitbox.ownerOf(result.Instance)
		if model and not skip[model] and not (skipPlayers and Players:GetPlayerFromCharacter(model)) then
			return model, math.min(travelled, length), result.Position, Hitbox.zoneOf(model, result.Instance)
		end
		if travelled >= length then
			break
		end
	end
	return nil, length, nil, nil
end

local ZONE_BY_NAME: { [string]: Zone } = {
	Head = "Head",
	UpperTorso = "Torso",
	LowerTorso = "Torso",
	HumanoidRootPart = "Torso",
	Torso = "Torso",
	LeftUpperArm = "Limb",
	LeftLowerArm = "Limb",
	LeftHand = "Limb",
	RightUpperArm = "Limb",
	RightLowerArm = "Limb",
	RightHand = "Limb",
	LeftUpperLeg = "Limb",
	LeftLowerLeg = "Limb",
	LeftFoot = "Limb",
	RightUpperLeg = "Limb",
	RightLowerLeg = "Limb",
	RightFoot = "Limb",
	["Left Arm"] = "Limb",
	["Right Arm"] = "Limb",
	["Left Leg"] = "Limb",
	["Right Leg"] = "Limb",
}
local ZONE_ATTRIBUTES: { [string]: Zone } = { Head = "Head", Torso = "Torso", Limb = "Limb", Weak = "Weak" }

-- La zona de "part" (una pieza de "model"), por este orden: su atributo "Zone" ("Head", "Torso", "Limb" o
-- "Weak"); su atributo "WeakPoint" a true (punto débil de un jefe); su nombre R15 o R6; si no, el torso.
-- También miran los atributos los grupos entre la pieza y el modelo (el más cercano gana).
function Hitbox.zoneOf(model: Model, part: Instance): Zone
	local current: Instance? = part
	while current and current ~= model do
		local tagged = current:GetAttribute("Zone")
		local zone = if typeof(tagged) == "string" then ZONE_ATTRIBUTES[tagged] else nil
		if zone then
			return zone
		end
		if current:GetAttribute("WeakPoint") == true then
			return "Weak"
		end
		current = current.Parent
	end
	return ZONE_BY_NAME[part.Name] or "Torso"
end

-- Un eje de la prueba segmento-caja (método de las losas): el intervalo [tMin, tMax] del segmento que sigue
-- dentro de la losa de mitad de grosor "h" (posición "p" y dirección "d" en ese eje). Vacío: tMin > tMax.
local function slab(p: number, d: number, h: number, tMin: number, tMax: number): (number, number)
	if math.abs(d) < 1e-9 then
		if math.abs(p) > h then
			return 1, 0
		end
		return tMin, tMax
	end
	local t1, t2 = (-h - p) / d, (h - p) / d
	if t1 > t2 then
		t1, t2 = t2, t1
	end
	return math.max(tMin, t1), math.min(tMax, t2)
end

-- Distancia a lo largo del segmento (origen "o", unitario "u", largo "length") hasta que entra en la caja
-- orientada de "cframe" y mitad de lado "half", o nil. Si ya empieza dentro, 0.
local function segmentBox(o: Vector3, u: Vector3, length: number, cframe: CFrame, half: Vector3): number?
	local localOrigin = cframe:PointToObjectSpace(o)
	local localDirection = cframe:VectorToObjectSpace(u)
	local tMin, tMax = slab(localOrigin.X, localDirection.X, half.X, 0, length)
	tMin, tMax = slab(localOrigin.Y, localDirection.Y, half.Y, tMin, tMax)
	tMin, tMax = slab(localOrigin.Z, localDirection.Z, half.Z, tMin, tMax)
	return if tMin <= tMax then tMin else nil
end

local PART_PADDING = Vector3.one * ZONES.PartPadding
local POSE_PARTS = PositionHistory.POSE_PARTS
-- Búferes que se reutilizan en cada prueba (sin crear tablas): la pose de las 15 piezas y su tamaño.
local poseCFrames: { CFrame } = table.create(#POSE_PARTS, CFrame.identity)
local poseSizes: { Vector3 } = table.create(#POSE_PARTS, Vector3.zero)

-- Prueba el segmento contra las piezas de "model" y su cabeza. Con "rewind" y historia de pose
-- (PositionHistory.poseInto), las piezas son las de entonces colocadas en "past"; si no, las actuales
-- desplazadas "shift" (la raíz de entonces menos la de ahora). La cabeza es una esfera (radio ya ensanchado
-- por HeadRadiusScale); el resto, cajas con PartPadding de margen. Devuelve lo que avanza hasta la pieza más
-- cercana y su zona; si la cabeza y otra pieza se tocan casi a la vez, la cabeza. nil si no toca ninguna.
-- "headCenter" y "headRadius" son los actuales (desplazados) por si no hay pose.
local function nearestPiece(
	model: Model,
	rewind: number,
	past: Vector3?,
	shift: Vector3,
	origin: Vector3,
	direction: Vector3,
	length: number,
	headCenter: Vector3?,
	headRadius: number
): (number?, Zone)
	local bestAlong: number? = nil
	local bestZone: Zone = "Torso"
	local hasPose = rewind > 0 and past ~= nil and PositionHistory.poseInto(model, rewind, poseCFrames, poseSizes)
	local headAlong: number? = nil
	if hasPose then
		local pastPosition = past :: Vector3
		for index, name in POSE_PARTS do
			local size = poseSizes[index]
			if size ~= Vector3.zero then
				local placed = poseCFrames[index] + pastPosition
				if name == "Head" then
					local radius = math.max(size.X, size.Y, size.Z) / 2 * HEADSHOT.HeadRadiusScale
					headAlong = segmentSphere(origin, direction, length, placed.Position, radius)
				else
					local along = segmentBox(origin, direction, length, placed, size / 2 + PART_PADDING)
					if along and (not bestAlong or along < bestAlong) then
						bestAlong, bestZone = along, ZONE_BY_NAME[name] or "Torso"
					end
				end
			end
		end
	else
		if headCenter then
			headAlong = segmentSphere(origin, direction, length, headCenter, headRadius)
		end
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and child.Name ~= "Head" and child.Name ~= "HumanoidRootPart" then
				local along = segmentBox(origin, direction, length, child.CFrame + shift, child.Size / 2 + PART_PADDING)
				if along and (not bestAlong or along < bestAlong) then
					bestAlong, bestZone = along, Hitbox.zoneOf(model, child)
				end
			end
		end
	end
	if headAlong and (not bestAlong or headAlong <= bestAlong + HEAD_TIE_STUDS) then
		return headAlong, "Head"
	end
	return bestAlong, bestZone
end

-- Un punto que avanza "displacement" desde "origin" solo entre los personajes de jugadores vivos que no
-- estén en "skip" (Fase 15, V7; por piezas desde la Fase 19, W6). Cada uno se prueba donde estaba hace
-- "rewind" segundos (el lag del tirador). Primero, como filtro barato, la cápsula del cuerpo y la esfera de
-- la cabeza (Config.Combat.Headshot) trasladadas a esa posición; solo si acierta alguna se prueba pieza a
-- pieza (nearestPiece). Devuelve el primero a lo largo del segmento: el modelo, lo que ha avanzado, el
-- punto de contacto y la zona ("Head", "Torso" o "Limb"). Sin acierto, (nil, largo, nil, nil).
function Hitbox.sweepBodies(
	origin: Vector3,
	displacement: Vector3,
	rewind: number,
	skip: { [Model]: boolean }
): (Model?, number, Vector3?, Zone?)
	local length = displacement.Magnitude
	if length < 1e-3 then
		return nil, 0, nil, nil
	end
	local direction = displacement / length
	local bestModel: Model? = nil
	local bestAlong = math.huge
	local bestZone: Zone = "Torso"
	for _, player in Players:GetPlayers() do
		local model = player.Character
		local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
		local shape = if model and humanoid and humanoid.Health > 0 and not skip[model] then bodyShape(model) else nil
		if model and shape then
			local past = if rewind > 0 then PositionHistory.at(model, rewind) else nil
			local shift = if past then past - shape.root.Position else Vector3.zero
			local headCenter = if shape.headCenter then shape.headCenter + shift else nil
			local near = (
				headCenter ~= nil and segmentSphere(origin, direction, length, headCenter, shape.headRadius) ~= nil
			)
				or segmentCapsule(
						origin,
						direction,
						length,
						shape.feet + shift,
						shape.neck + shift,
						HEADSHOT.BodyRadius + ZONES.FilterExtraStuds
					)
					~= nil
			if near then
				local along, zone =
					nearestPiece(model, rewind, past, shift, origin, direction, length, headCenter, shape.headRadius)
				if along and along < bestAlong then
					bestModel, bestAlong, bestZone = model, along, zone
				end
			end
		end
	end
	if not bestModel then
		return nil, length, nil, nil
	end
	return bestModel, bestAlong, origin + direction * bestAlong, bestZone
end

-- Rehace la lista de combatientes cuando cambia y empieza a guardar sus posiciones. Lo llama
-- CombatService:Start; antes, la lista se rehace en cada consulta.
function Hitbox.start()
	if started then
		return
	end
	started = true
	local function changed()
		dirty = true
	end
	CollectionService:GetInstanceAddedSignal(ENEMY_TAG):Connect(changed)
	CollectionService:GetInstanceRemovedSignal(ENEMY_TAG):Connect(changed)
	local function watch(player: Player)
		player.CharacterAdded:Connect(changed)
		player.CharacterRemoving:Connect(changed)
		changed()
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(changed)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	PositionHistory.start(Hitbox.combatants)
end

return Hitbox
