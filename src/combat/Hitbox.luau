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
--   - rewound: dónde estaba un combatiente hace unos segundos (Combat/PositionHistory), para el lag.
-- Combatientes: los modelos con la etiqueta Config.Combat.EnemyTag (monos, jefes, muñecos) y los
-- personajes de los jugadores. La lista se rehace solo cuando cambia, y las consultas de piezas buscan
-- solo entre ellos (lista de inclusión), no en todo el mapa.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PositionHistory = require(script.Parent.PositionHistory)

local ENEMY_TAG = Config.Combat.EnemyTag

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

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
sightParams.IgnoreWater = true
sightParams.RespectCanCollide = true

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

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

-- Combatientes con alguna pieza dentro de la caja (o, con "rewind", con la raíz dentro donde
-- estaban entonces, con 1 stud de margen por el cuerpo). Ver Query.
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
		local half = size / 2 + Vector3.one
		for _, model in combatants do
			local past = if seen[model] or not model.Parent then nil else PositionHistory.at(model, rewind)
			if past then
				local localPoint = cframe:PointToObjectSpace(past)
				if
					math.abs(localPoint.X) <= half.X
					and math.abs(localPoint.Y) <= half.Y
					and math.abs(localPoint.Z) <= half.Z
				then
					consider(model)
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
