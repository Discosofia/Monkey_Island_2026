--!strict
-- Actores de las cinemáticas (Fase 25). Actors.spawn(def, anchor, ctx) crea o encuentra el modelo de un
-- actor según def.kind:
--   dummy        rig R15 vestido con el equipo del juego (ArmorModels.wear + WeaponTools.build, como Portada).
--                def = { kind, role?, armor?, outfit?, grade?, weapon?, skin?, pos?, yaw?, skinColor?, pantsColor? }
--   localPlayer  el personaje del jugador local (no se crea ni se borra); con def.pos lo coloca.
--   boss         el modelo del jefe que ya está en el mundo, buscado por su atributo "Boss" (def.id opcional).
--   prop         lo que devuelva def.build(anchor, ctx) (un Model con lo que haga falta).
-- pos (relativa al anchor) es donde pisa el suelo; yaw, el giro en grados. Actors.cleanup(ctx) destruye lo
-- creado y devuelve a su sitio lo que se movió sin ser nuestro (jugador, jefe).
--
-- Sin dependencias de Remotes, Settings ni CombatClient. Lo que viene del place se inyecta:
--   Actors.setDummyFactory(fn)  crea el rig R15 base cuando CreateHumanoidModelFromDescription no se puede usar
--                               (en el cliente puede no estar disponible: G1b registra una plantilla R15
--                               guardada en ReplicatedStorage). fn(def) -> Model?
--   Actors.setAnimator(fn)      reproduce una animación en un actor: fn(actor, action, event). El controlador
--                               del place la enlaza a BodyAnimations.playOn (CombatClient) o a MonkeyAnimator.
-- Actors.install(Sequencer) registra los eventos anim y move y el spawn/cleanup de scene.actors.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ArmorModels = require(script.Parent.Parent.ArmorModels)
local Sequencer = require(script.Parent.Sequencer)
local WeaponTools = require(script.Parent.Parent.WeaponTools)

local Actors = {}

export type ActorDef = {
	kind: string,
	role: string?,
	armor: string?,
	outfit: string?,
	grade: number?,
	weapon: string?,
	skin: string?,
	id: string?,
	pos: Vector3?,
	yaw: number?,
	skinColor: Color3?,
	pantsColor: Color3?,
	build: ((anchor: CFrame, ctx: Sequencer.Context) -> Model)?,
	[string]: any,
}
export type DummyFactory = (def: ActorDef) -> Model?
export type Animator = (actor: Model, action: string, event: Sequencer.Event) -> ()

local DEFAULT_SKIN = Color3.fromRGB(255, 204, 153)
local DEFAULT_PANTS = Color3.fromRGB(70, 60, 50)
local DEFAULT_ROLE = "Guerrero"

local dummyFactory: DummyFactory? = nil
local animator: Animator? = nil
local warnedAnimator = false

function Actors.setDummyFactory(fn: DummyFactory?)
	dummyFactory = fn
end

function Actors.setAnimator(fn: Animator?)
	animator = fn
end

-- Rig R15 base: el del Players:CreateHumanoidModelFromDescription (funciona en el servidor y en modo
-- edición), o el de la fábrica inyectada si hay y aquel no se puede usar.
local function baseRig(def: ActorDef): Model?
	if dummyFactory then
		local rig = dummyFactory(def)
		if rig then
			return rig
		end
	end
	local ok, rig = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local skin = def.skinColor or DEFAULT_SKIN
		local pants = def.pantsColor or DEFAULT_PANTS
		description.HeadColor = skin
		description.TorsoColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.LeftLegColor = pants
		description.RightLegColor = pants
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok then
		return rig :: Model
	end
	warn("Actors: no se puede crear el maniquí R15 aquí; registra Actors.setDummyFactory")
	return nil
end

-- Pone el arma en la mano derecha, soldada por su agarre (igual que Portada).
local function holdWeapon(rig: Model, weaponId: string, skinId: string?)
	local ok, tool = pcall(WeaponTools.build, weaponId, skinId)
	if not ok then
		warn(`Actors: no se puede construir el arma {weaponId}: {tool}`)
		return
	end
	local hand = rig:FindFirstChild("RightHand")
	local handle = (tool :: Tool):FindFirstChild("Handle")
	if not (hand and hand:IsA("BasePart") and handle and handle:IsA("BasePart")) then
		(tool :: Tool):Destroy()
		return
	end
	(tool :: Tool).Parent = rig
	local grip = hand:FindFirstChild("RightGripAttachment") :: Attachment?
	local weld = Instance.new("Weld")
	weld.Name = "RightGrip"
	weld.Part0 = hand
	weld.Part1 = handle
	weld.C0 = if grip then grip.CFrame else CFrame.identity
	weld.C1 = (tool :: Tool).Grip
	weld.Parent = hand
end

-- Coloca "model" de pie en "ground" (relativo a anchor), girado "yaw" grados, por su raíz (no por la caja,
-- para que el arma y el traje no lo levanten del suelo).
local function place(model: Model, anchor: CFrame, ground: Vector3, yaw: number)
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
		local lift = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
		model:SetAttribute("CinematicLift", lift)
		model:PivotTo(anchor * CFrame.new(ground + Vector3.new(0, lift, 0)) * CFrame.Angles(0, math.rad(yaw), 0))
	else
		model:PivotTo(anchor * CFrame.new(ground) * CFrame.Angles(0, math.rad(yaw), 0))
	end
end

local function created(ctx: Sequencer.Context): { Instance }
	local list = ctx._created
	if not list then
		list = {}
		ctx._created = list
	end
	return list
end

local function spawnDummy(def: ActorDef, anchor: CFrame, ctx: Sequencer.Context): Model?
	local rig = baseRig(def)
	if not rig then
		return nil
	end
	table.insert(created(ctx), rig)
	local role = def.role or DEFAULT_ROLE
	rig.Name = `Cinematic_{role}`
	if def.armor or def.outfit then
		ArmorModels.wear(rig, def.armor, role, def.outfit, def.grade or ArmorModels.MAX_GRADE)
	end
	local weaponId = def.weapon or WeaponTools.roleWeapon(role, WeaponTools.MAX_LEVEL)
	if weaponId then
		holdWeapon(rig, weaponId, def.skin)
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	place(rig, anchor, def.pos or Vector3.zero, def.yaw or 0)
	-- La raíz anclada deja el rig quieto donde se pone; los miembros siguen moviéndose con las animaciones.
	local root = rig:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
	end
	rig.Parent = Workspace
	return rig
end

local function findBoss(id: string?): Model?
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("Model") then
			local boss = descendant:GetAttribute("Boss")
			if boss ~= nil and (id == nil or boss == id) then
				return descendant
			end
		end
	end
	return nil
end

-- Crea (o encuentra) el actor de "def". Devuelve nil si no se puede, con un aviso.
function Actors.spawn(def: ActorDef, anchor: CFrame, ctx: Sequencer.Context): Model?
	if def.kind == "dummy" then
		return spawnDummy(def, anchor, ctx)
	elseif def.kind == "localPlayer" then
		local player = Players.LocalPlayer
		local character = if player then player.Character else nil
		if character and def.pos then
			place(character, anchor, def.pos, def.yaw or 0)
		end
		return character
	elseif def.kind == "boss" then
		return findBoss(def.id)
	elseif def.kind == "prop" then
		if not def.build then
			warn("Actors: un prop necesita def.build")
			return nil
		end
		local model = def.build(anchor, ctx)
		table.insert(created(ctx), model)
		if not model.Parent then
			model.Parent = Workspace
		end
		return model
	end
	warn(`Actors: tipo de actor desconocido ({def.kind})`)
	return nil
end

-- Destruye lo creado por la escena, cancela los movimientos en curso y devuelve a su sitio a los actores
-- que no eran nuestros (jugador, jefe) si un evento move los movió.
function Actors.cleanup(ctx: Sequencer.Context)
	local tweens = ctx._tweens
	if tweens then
		for _, entry in tweens do
			entry.tween:Cancel()
			entry.value:Destroy()
		end
		ctx._tweens = nil
	end
	local moved = ctx._restore
	if moved then
		for model, pivot in moved do
			if model.Parent then
				model:PivotTo(pivot)
			end
		end
		ctx._restore = nil
	end
	local list = ctx._created
	if list then
		for _, instance in list do
			instance:Destroy()
		end
		ctx._created = nil
	end
	ctx.actors = nil
end

-- Mueve "actor" hasta "pos" (relativa al anchor) en "seconds". Sin "seconds" o con "instant", de golpe.
local function moveActor(actor: Model, event: Sequencer.Event, ctx: Sequencer.Context, instant: boolean)
	local anchor: CFrame = ctx.anchor or CFrame.identity
	local from = actor:GetPivot()
	local lift = actor:GetAttribute("CinematicLift") or 0
	local target = anchor:PointToWorldSpace((event.pos :: Vector3) + Vector3.new(0, lift, 0))
	local rotation = if event.yaw then (anchor * CFrame.Angles(0, math.rad(event.yaw), 0)).Rotation else from.Rotation
	local to = CFrame.new(target) * rotation

	-- Lo que no hemos creado (jugador, jefe) se devuelve a su sitio al acabar.
	local isOurs = false
	for _, instance in ctx._created or {} do
		if instance == actor then
			isOurs = true
		end
	end
	if not isOurs then
		local restore = ctx._restore
		if not restore then
			restore = {}
			ctx._restore = restore
		end
		if not restore[actor] then
			restore[actor] = from
		end
	end

	local seconds: number = event.seconds or 0
	if instant or seconds <= 0 then
		actor:PivotTo(to)
		return
	end
	local value = Instance.new("NumberValue")
	local tweens = ctx._tweens
	if not tweens then
		tweens = {}
		ctx._tweens = tweens
	end
	local info = TweenInfo.new(seconds, event.easing or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local tween = TweenService:Create(value, info, { Value = 1 })
	local entry = { tween = tween, value = value }
	table.insert(tweens, entry)
	value.Changed:Connect(function(alpha: number)
		if actor.Parent then
			actor:PivotTo(from:Lerp(to, alpha))
		end
	end)
	tween.Completed:Connect(function()
		local index = table.find(tweens, entry)
		if index then
			table.remove(tweens, index)
		end
		value:Destroy()
	end)
	tween:Play()
end

local function actorOf(event: Sequencer.Event, ctx: Sequencer.Context): Model?
	local actors = ctx.actors
	local actor = if actors and event.actor then actors[event.actor] else nil
	if not actor then
		warn(`Actors: el evento {event.kind} pide un actor que no existe ({event.actor})`)
	end
	return actor
end

-- Registra en el Sequencer: scene.actors (se crean al empezar y se limpian al terminar) y los eventos
--   anim { actor, action, speed?, seconds?, server? }  llama al animador inyectado; con server = true lo
--                                                       lanza el servidor y el cliente lo ignora.
--   move { actor, pos, yaw?, seconds?, easing? }       mueve el actor hasta pos (relativa al anchor).
function Actors.install(sequencer: typeof(Sequencer))
	sequencer.addHooks({
		start = function(scene, ctx)
			local spawned: { [string]: Model } = {}
			ctx.actors = spawned
			for name, def in scene.actors or {} do
				local model = Actors.spawn(def, ctx.anchor or CFrame.identity, ctx)
				if model then
					spawned[name] = model
				end
			end
		end,
		finish = function(_, ctx)
			Actors.cleanup(ctx)
		end,
	})
	sequencer.registerHandler("anim", function(event, ctx)
		if event.server or ctx.seeking then
			return
		end
		local actor = actorOf(event, ctx)
		if not actor then
			return
		end
		if not animator then
			if not warnedAnimator then
				warnedAnimator = true
				warn("Actors: no hay animador registrado (Actors.setAnimator); se ignoran los eventos anim")
			end
			return
		end
		animator(actor, event.action, event)
	end)
	sequencer.registerHandler("move", function(event, ctx)
		local actor = actorOf(event, ctx)
		if actor then
			moveActor(actor, event, ctx, ctx.seeking == true)
		end
	end)
end

return Actors
