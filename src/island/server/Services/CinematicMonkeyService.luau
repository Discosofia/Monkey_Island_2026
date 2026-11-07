--!strict
-- Monos de las escenas de batalla (Fase 25, G5): para grabar, no salen en el juego. Registra el evento de servidor
-- «monkey» de CinematicService. Los monos son instancias de servidor visibles a todos, sin IA, sin etiqueta Enemy y
-- sin daño: solo un modelo con su MonkeyAnimator. Llevan el atributo CinematicActor (el nombre del evento), el
-- atributo CinematicOwner (el UserId de quien ve la escena) y la etiqueta Config.Combat.CinematicActorTag, y los
-- borra el final de la ejecución (CinematicService.onEnd).
--
--   monkey { t, server = true, name, species?, alpha?, at?, yaw?, action?, move?, despawn? }
--     name     nombre del mono en la escena (el que usa el evento abilityFx del cliente y los bocadillos del cómic).
--     species  id de Data/Monkeys. Con species (y at) crea el mono; sin species, el evento actúa sobre el que ya existe.
--     alpha    boolean, solo al crear con species: el mono alfa de la especie (más grande y de colores marcados;
--              MonkeyModels.spawn con alpha). Sigue sin IA ni etiqueta Enemy.
--     at       Vector3 en el marco del anchor: solo cuentan X y Z; el suelo se busca con un rayo solo contra Terrain.
--     yaw      grados en el marco del anchor (0 mira a -Z, 180 a +Z), como los maniquíes (Actors). Sin move, gira ya.
--     action   Idle | Attack | Hurt | Roar | Throw | Howl | Stomp | Pounce… (Data/MonkeyAnimations) o «Die»: corta
--              sus animaciones, el «¡puf!» de caricatura del juego (Combat/Poof) y desaparece. «Death» también se
--              puede pedir, pero el juego no lo usa (el mono no cae muerto, por el cuestionario de madurez).
--     move     { pos = Vector3 (marco del anchor), seconds, yaw? }: anda en línea recta hasta pos con un Tween de la
--              raíz anclada. Mira hacia donde va (o a «move.yaw» al llegar) y su animación pasa a Walk o Run según
--              la velocidad (MonkeyAnimator.setSpeed). Un mono nuevo con move empieza a andar en el acto.
--     despawn  true: lo borra al momento, sin «¡puf!».

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local MonkeyAnimator = require(ServerScriptService.Combat.Monkeys.MonkeyAnimator)
local MonkeyModels = require(ServerScriptService.Combat.Monkeys.MonkeyModels)
local Poof = require(ServerScriptService.Combat.Poof)
local CinematicService = require(script.Parent.CinematicService)

local FOLDER_NAME = "CinematicActors"
local GROUND_RAY_UP = 60 -- studs sobre el anchor desde donde cae el rayo al suelo
local GROUND_RAY_DOWN = 220
local DIE_REMOVE_SECONDS = 0.2 -- lo que tarda en borrarse el mono tras el «¡puf!»
-- Acciones que además de la animación llevan la voz de su especie (Data/Sounds: Monkey<Small|Medium|Large><acción>).
local VOICED = { Roar = true, Hurt = true, Attack = true, Howl = true }

local CinematicMonkeyService = {}

type Entry = {
	model: Model,
	root: BasePart,
	lift: number, -- altura de la raíz sobre el suelo
	definition: Monkeys.MonkeyDefinition,
	tween: Tween?,
}

type State = {
	monkeys: { [string]: Entry },
	owner: number?,
}

local folder: Folder? = nil

local function container(): Folder
	if folder and folder.Parent then
		return folder
	end
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = Workspace
		folder = created
	end
	return folder :: Folder
end

-- Suelo bajo un punto (X y Z del marco del anchor), buscado solo contra el Terrain.
local function groundAt(anchor: CFrame, at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local world = anchor:PointToWorldSpace(Vector3.new(at.X, 0, at.Z))
	local hit = Workspace:Raycast(
		Vector3.new(world.X, anchor.Position.Y + GROUND_RAY_UP, world.Z),
		Vector3.new(0, -GROUND_RAY_DOWN, 0),
		params
	)
	return if hit then hit.Position else world
end

local function stateOf(run: CinematicService.Run): State
	local existing = run.context.cinematicMonkeys
	if existing then
		return existing :: State
	end
	local owner: number? = nil
	local count = 0
	for player in run.audience do
		count += 1
		owner = player.UserId
	end
	local state: State = { monkeys = {}, owner = if count == 1 then owner else nil }
	run.context.cinematicMonkeys = state
	CinematicService.onEnd(run, function()
		for _, entry in state.monkeys do
			if entry.tween then
				entry.tween:Cancel()
			end
			entry.model:Destroy()
		end
		table.clear(state.monkeys)
	end)
	return state
end

local function anchorOf(run: CinematicService.Run): CFrame
	local anchor = run.args.anchor
	return if typeof(anchor) == "CFrame" then anchor else CFrame.identity
end

-- Giro en el mundo de "yaw" grados medidos en el marco del anchor.
local function rotationOf(anchor: CFrame, yaw: number): CFrame
	return anchor.Rotation * CFrame.Angles(0, math.rad(yaw), 0)
end

local function remove(state: State, name: string)
	local entry = state.monkeys[name]
	if not entry then
		return
	end
	state.monkeys[name] = nil
	if entry.tween then
		entry.tween:Cancel()
	end
	entry.model:Destroy()
end

local function spawnMonkey(state: State, run: CinematicService.Run, event: { [string]: any }): Entry?
	local definition = Monkeys[event.species]
	if not definition then
		warn(`[CinematicMonkeyService] Especie desconocida: {event.species}`)
		return nil
	end
	local anchor = anchorOf(run)
	local at: Vector3 = event.at or Vector3.zero
	local alpha = event.alpha == true
	local model = MonkeyModels.spawn(event.species, definition, groundAt(anchor, at), alpha)
	local root = model.PrimaryPart :: BasePart
	local lift = MonkeyModels.rootHeight(MonkeyModels.scaleOf(definition, alpha))
	model:SetAttribute("CinematicActor", event.name)
	model:SetAttribute("CinematicOwner", state.owner)
	CollectionService:AddTag(model, Config.Combat.CinematicActorTag)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	model:PivotTo(CFrame.new(root.Position) * rotationOf(anchor, event.yaw or 0))
	root.Anchored = true
	model.Parent = container()
	MonkeyAnimator.attach(model)
	local entry: Entry = { model = model, root = root, lift = lift, definition = definition, tween = nil }
	state.monkeys[event.name] = entry
	return entry
end

local function moveMonkey(entry: Entry, run: CinematicService.Run, move: { [string]: any })
	local anchor = anchorOf(run)
	local seconds: number = math.max(move.seconds or 1, 0.05)
	local goalGround = groundAt(anchor, move.pos)
	local goalPosition = goalGround + Vector3.new(0, entry.lift, 0)
	local from = entry.root.Position
	local flat = Vector3.new(goalPosition.X - from.X, 0, goalPosition.Z - from.Z)
	-- Mira hacia donde va, salvo que pida otro giro al llegar.
	local travel = if flat.Magnitude > 0.05 then CFrame.lookAt(Vector3.zero, flat) else entry.root.CFrame.Rotation
	if entry.tween then
		entry.tween:Cancel()
	end
	entry.model:PivotTo(CFrame.new(from) * travel)
	local rotation = if move.yaw ~= nil then rotationOf(anchor, move.yaw) else travel
	MonkeyAnimator.setSpeed(entry.model, flat.Magnitude / seconds)
	local tween = TweenService:Create(
		entry.root,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(goalPosition) * rotation }
	)
	entry.tween = tween
	tween.Completed:Connect(function()
		if entry.tween == tween then
			entry.tween = nil
			if entry.model.Parent then
				MonkeyAnimator.setSpeed(entry.model, 0)
			end
		end
	end)
	tween:Play()
end

local function act(state: State, name: string, entry: Entry, action: string)
	if action == "Die" then
		MonkeyAnimator.die(entry.model)
		Poof.vanish(entry.model)
		task.delay(DIE_REMOVE_SECONDS, function()
			if state.monkeys[name] == entry then
				remove(state, name)
			end
		end)
		return
	end
	-- Idle, Walk y Run son la locomoción (en bucle): se eligen por velocidad, no se lanzan como una acción.
	if action == "Idle" then
		MonkeyAnimator.setSpeed(entry.model, 0)
		return
	end
	MonkeyAnimator.play(entry.model, action :: any)
	if VOICED[action] then
		Sfx.play(`Monkey{entry.definition.voice}{action}`, entry.root)
	end
end

local function onMonkey(event: { [string]: any }, run: CinematicService.Run)
	local name = event.name
	if typeof(name) ~= "string" then
		warn("[CinematicMonkeyService] El evento monkey necesita un nombre")
		return
	end
	local state = stateOf(run)
	if event.despawn == true then
		remove(state, name)
		return
	end
	local entry = state.monkeys[name]
	if event.species ~= nil and not entry then
		entry = spawnMonkey(state, run, event)
	end
	if not entry then
		warn(`[CinematicMonkeyService] No hay un mono llamado {name} en la escena {run.id}`)
		return
	end
	if event.move == nil and event.yaw ~= nil and entry.model.Parent and event.species == nil then
		entry.model:PivotTo(CFrame.new(entry.root.Position) * rotationOf(anchorOf(run), event.yaw))
	end
	if event.action ~= nil then
		act(state, name, entry, event.action)
	end
	if event.move ~= nil then
		moveMonkey(entry, run, event.move)
	end
end

-- Radio (studs) en que se esconden los monos reales alrededor de cada punto del evento hideEnemies.
local HIDE_RADIUS = 200

type HiddenProperty = { instance: Instance, property: string, value: any }

-- hideEnemies { centers = { Vector3 }, radius? }: esconde a los monos reales (etiqueta Enemy) que estén a menos de
-- "radius" de alguno de esos puntos (mundo, no relativos al anchor) mientras dura la escena: sin cuerpo, cartel ni
-- partículas. Se repasa cada HIDE_SCAN_SECONDS porque MonkeyService genera monos nuevos al llegar el avatar al claro.
-- Los de la cinemática (CinematicActor) no llevan la etiqueta Enemy y no se tocan. Al acabar se devuelve cada
-- propiedad a su valor. Solo esconde: la escena debe llevar freeze para que no ataquen sin verse.
local HIDE_SCAN_SECONDS = 0.5

local function onHideEnemies(event: { [string]: any }, run: CinematicService.Run)
	local centers = event.centers :: { Vector3 }
	local radius: number = event.radius or HIDE_RADIUS
	local saved: { HiddenProperty } = {}
	local done: { [Instance]: boolean } = {}
	local function hide(instance: Instance, property: string, hidden: any)
		local target: any = instance
		table.insert(saved, { instance = instance, property = property, value = target[property] })
		target[property] = hidden
	end
	local function hideModel(model: Model)
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") or descendant:IsA("Decal") then
				hide(descendant, "Transparency", 1)
			elseif
				descendant:IsA("BillboardGui")
				or descendant:IsA("SurfaceGui")
				or descendant:IsA("ParticleEmitter")
				or descendant:IsA("Light")
				or descendant:IsA("Beam")
				or descendant:IsA("Trail")
			then
				hide(descendant, "Enabled", false)
			end
		end
	end
	local function scan()
		for _, model in CollectionService:GetTagged("Enemy") do
			if model:IsA("Model") and not done[model] then
				local position = model:GetPivot().Position
				for _, center in centers do
					if (position - center).Magnitude <= radius then
						done[model] = true
						hideModel(model)
						break
					end
				end
			end
		end
	end
	task.spawn(function()
		while not run.finished do
			scan()
			task.wait(HIDE_SCAN_SECONDS)
		end
	end)
	CinematicService.onEnd(run, function()
		for _, item in saved do
			if item.instance.Parent then
				local target: any = item.instance
				target[item.property] = item.value
			end
		end
	end)
end

function CinematicMonkeyService:Start()
	CinematicService.registerServerEvent("monkey", onMonkey)
	CinematicService.registerServerEvent("hideEnemies", onHideEnemies)
end

return CinematicMonkeyService
