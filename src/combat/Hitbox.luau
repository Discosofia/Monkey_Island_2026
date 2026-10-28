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
--     el mundo lo mira ray: así el decorado que no choca no para los disparos).
--   - sweepPlayers (Fase 15, V7): un punto que avanza solo entre los jugadores vivos, probado contra su
--     cabeza (esfera) y su cuerpo (cápsula vertical, de los pies al cuello) en la posición rebobinada por
--     el lag del tirador (Config.Combat.Headshot). Dice cuál es el primero y si lo toca en la cabeza.
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
-- Si cabeza y cuerpo se tocan a distancias que difieren menos de esto (studs), cuenta la cabeza.
local HEAD_TIE_STUDS = 0.05

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
function Hitbox.sweepCombatants(
	origin: Vector3,
	radius: number,
	displacement: Vector3,
	skip: { [Model]: boolean }
): (Model?, number, Vector3?)
	Hitbox.combatants()
	local length = displacement.Magnitude
	if length < 1e-3 then
		return nil, 0, nil
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
			return nil, length, nil
		end
		travelled += math.max(result.Distance, 0.05)
		local model = Hitbox.ownerOf(result.Instance)
		if model and not skip[model] then
			return model, math.min(travelled, length), result.Position
		end
		if travelled >= length then
			break
		end
	end
	return nil, length, nil
end

-- Un punto que avanza "displacement" desde "origin" solo entre los personajes de jugadores vivos que no
-- estén en "skip" (Fase 15, V7). Cada uno se prueba donde estaba hace "rewind" segundos (el lag del
-- tirador): su cuerpo se traslada desde la raíz actual a esa posición pasada. Contra la esfera de la
-- cabeza y la cápsula del cuerpo (Config.Combat.Headshot); el grosor está en esos radios. Devuelve el
-- primero a lo largo del segmento: el modelo, lo que ha avanzado, el punto de contacto y si es la cabeza
-- (si cabeza y cuerpo se tocan casi a la vez, cuenta la cabeza).
function Hitbox.sweepPlayers(
	origin: Vector3,
	displacement: Vector3,
	rewind: number,
	skip: { [Model]: boolean }
): (Model?, number, Vector3?, boolean)
	local length = displacement.Magnitude
	if length < 1e-3 then
		return nil, 0, nil, false
	end
	local direction = displacement / length
	local bestModel: Model? = nil
	local bestAlong = math.huge
	local bestHead = false
	for _, player in Players:GetPlayers() do
		local model = player.Character
		local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
		local shape = if model and humanoid and humanoid.Health > 0 and not skip[model] then bodyShape(model) else nil
		if model and shape then
			local past = if rewind > 0 then PositionHistory.at(model, rewind) else nil
			local shift = if past then past - shape.root.Position else Vector3.zero
			local headAlong: number? = nil
			if shape.headCenter then
				headAlong = segmentSphere(origin, direction, length, shape.headCenter + shift, shape.headRadius)
			end
			local bodyAlong =
				segmentCapsule(origin, direction, length, shape.feet + shift, shape.neck + shift, HEADSHOT.BodyRadius)
			local along = headAlong
			local isHead = headAlong ~= nil
			if bodyAlong and (not headAlong or bodyAlong < headAlong - HEAD_TIE_STUDS) then
				along = bodyAlong
				isHead = false
			end
			if along and along < bestAlong then
				bestModel, bestAlong, bestHead = model, along, isHead
			end
		end
	end
	if not bestModel then
		return nil, length, nil, false
	end
	return bestModel, bestAlong, origin + direction * bestAlong, bestHead
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
