--!strict
-- Actores de las cinemáticas (Fase 25). Actors.spawn(def, anchor, ctx) crea o encuentra el modelo de un
-- actor según def.kind:
--   dummy        rig R15 vestido con el equipo del juego (ArmorModels.wear + WeaponTools.build, como Portada).
--                def = { kind, role?, armor?, outfit?, grade?, weapon?, skin?, pos?, yaw?, skinColor?, pantsColor?, snap?, ballGear?, team? }
--                team = "Jaguar" | "Quetzal": un brazalete y una capa corta en el color del bando (Config.Arena.Teams), que se ve
--                también de espalda; sirve para distinguir bandos sin cambiar la armadura.
--                snap = true: la Y sale de un rayo al Terrain (al colocarlo y en cada move), no de pos.
--                torch = true: lleva una antorcha encendida en la mano izquierda (WeaponTools.buildTorch, soldada como lo hace
--                TorchService), con el atributo CinematicTorch en su modelo; el evento torch de BattleActor la apaga y la enciende.
--                weapon = false: sin arma (por defecto lleva la de su rol). labWeapon = id de Data/LabWeapons: lleva esa arma del
--                Laboratorio con el aspecto de `faction` ("Guardians" | "Pirates") y, en vez de WeaponCarry, su pose de apuntar
--                (Aim*, Data/WeaponAim). ballGear = "Jaguar" | "Quetzal": lleva el equipo
--                del Juego de pelota de ese bando (Shared/BallgameGear). Sin snap, la Y de pos es la del suelo (la cancha de
--                Dunas son piezas, no Terrain: el suelo está en y = 0 de su anchor).
--   localPlayer  el personaje del jugador local (no se crea ni se borra); con def.pos lo coloca (y se le devuelve su sitio
--                al acabar). snap = true: la Y de pos y de cada `move` sale de un rayo al Terrain, como en un maniquí.
--                ballGear: le pone el equipo del Juego de pelota solo en este cliente y se lo quita al acabar.
--   boss         el modelo del jefe que ya está en el mundo, buscado por su atributo "Boss" (def.id opcional).
--   prop         lo que devuelva def.build(anchor, ctx) (un Model con lo que haga falta). Puede usar
--                Cinematics/MountedRider.build(mountId, character?, { pose? }): una montura con su jinete sentado.
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

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ArmorModels = require(script.Parent.Parent.ArmorModels)
local BallgameGear = require(script.Parent.Parent.BallgameGear)
local Config = require(script.Parent.Parent.Config)
local LabUniforms = require(script.Parent.LabUniforms)
local LabWeapons = require(script.Parent.Parent.Data.LabWeapons)
local RescueCrew = require(script.Parent.RescueCrew)
local Sequencer = require(script.Parent.Sequencer)
local WeaponAim = require(script.Parent.Parent.Data.WeaponAim)
local WeaponTools = require(script.Parent.Parent.WeaponTools)

local Actors = {}

export type ActorDef = {
	kind: string,
	role: string?,
	armor: string?,
	outfit: string?,
	grade: number?,
	weapon: (string | boolean)?, -- false = sin arma
	labWeapon: string?, -- id de Data/LabWeapons: arma del Laboratorio (con `faction`)
	faction: ("Guardians" | "Pirates")?, -- aspecto del arma del Laboratorio
	ballGear: string?, -- "Jaguar" | "Quetzal": equipo del Juego de pelota
	team: string?, -- "Jaguar" | "Quetzal" (Config.Arena.Teams): brazalete y capa corta del color del equipo
	torch: boolean?, -- antorcha encendida en la mano izquierda
	copy: boolean?, -- localPlayer: dibuja una copia del personaje y esconde el real (el servidor no puede moverla)
	skin: string?,
	id: string?,
	pos: Vector3?,
	yaw: number?,
	snap: boolean?,
	skinColor: Color3?,
	pantsColor: Color3?,
	build: ((anchor: CFrame, ctx: Sequencer.Context) -> Model)?,
	[string]: any,
}
export type DummyFactory = (def: ActorDef) -> Model?
export type Animator = (actor: Model, action: string, event: Sequencer.Event) -> ()

local CINEMATIC_ACTOR_TAG = Config.Combat.CinematicActorTag
local DEFAULT_SKIN = Color3.fromRGB(255, 204, 153)
local DEFAULT_PANTS = Color3.fromRGB(70, 60, 50)
local DEFAULT_ROLE = "Guerrero"
-- Cuánto sostiene un actor la pose de apuntar de su arma del Laboratorio (un evento anim la cambia antes).
local AIM_POSE_SECONDS = 600
-- Cómo agarra la mano la antorcha (copia de HAND_OFFSET en island/server/Services/TorchService.luau:28: ese módulo es del
-- servidor y no se puede requerir desde Shared): hacia delante y arriba, con la punta a -Z.
local TORCH_HAND_OFFSET = CFrame.new(0, -0.25, -0.05) * CFrame.Angles(math.rad(-55), 0, 0)
local TORCH_NAME = "AntorchaEnMano"

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

-- Snap al suelo (def.snap = true en un maniquí): la Y de "pos" (relativa al anchor) sale de un rayo contra el Terrain
-- desde 40 studs sobre ese punto del mundo y 120 hacia abajo, en vez de la Y relativa. Sin suelo, queda la Y de "pos".
local SNAP_RAY_UP = 40
local SNAP_RAY_DOWN = 120

local function snapToTerrain(anchor: CFrame, pos: Vector3): Vector3
	local world = anchor:PointToWorldSpace(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(world + Vector3.new(0, SNAP_RAY_UP, 0), Vector3.new(0, -SNAP_RAY_DOWN, 0), params)
	if not hit then
		return pos
	end
	return anchor:PointToObjectSpace(Vector3.new(world.X, hit.Position.Y, world.Z))
end

-- Lo mismo para otros módulos de cinemática (BattleActor): con CFrame.identity, `pos` es un punto del mundo.
function Actors.snapToTerrain(anchor: CFrame, pos: Vector3): Vector3
	return snapToTerrain(anchor, pos)
end

-- Altura de la raíz sobre el suelo de un rig R15 (cadera más media raíz).
local function liftOf(model: Model): number
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") then
		return (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
	end
	return 0
end

-- Apunta dónde estaba "model" antes de que la escena lo moviera, para devolverlo en Actors.cleanup.
local function remember(ctx: Sequencer.Context, model: Model)
	local restore = ctx._restore
	if not restore then
		restore = {}
		ctx._restore = restore
	end
	if not restore[model] then
		restore[model] = model:GetPivot()
	end
end

-- Coloca "model" de pie en "ground" (relativo a anchor), girado "yaw" grados, por su raíz (no por la caja,
-- para que el arma y el traje no lo levanten del suelo).
local function place(model: Model, anchor: CFrame, ground: Vector3, yaw: number)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
		local lift = liftOf(model)
		model:SetAttribute("CinematicLift", lift)
		model:PivotTo(anchor * CFrame.new(ground + Vector3.new(0, lift, 0)) * CFrame.Angles(0, math.rad(yaw), 0))
	else
		model:PivotTo(anchor * CFrame.new(ground) * CFrame.Angles(0, math.rad(yaw), 0))
	end
end

-- Lleva todas las piezas del arma a donde la deja el agarre (RightGrip), antes de que el maniquí entre al mundo. Sin esto,
-- el Weld del agarre mueve solo el mango al entrar y las piezas unidas con WeldConstraint (llamas, grietas, cuerda)
-- toman su posición de la caja a medio camino: el cuerpo de malla (unido con Weld) queda bien y el resto, desplazado.
local function alignWeapon(rig: Model)
	local hand = rig:FindFirstChild("RightHand")
	local tool = rig:FindFirstChildOfClass("Tool")
	local handle = if tool then tool:FindFirstChild("Handle") else nil
	local grip = if hand then hand:FindFirstChild("RightGrip") else nil
	if not (hand and tool and handle and grip and handle:IsA("BasePart") and grip:IsA("Weld")) then
		return
	end
	local target = (hand :: BasePart).CFrame * grip.C0 * grip.C1:Inverse()
	local delta = target * (handle :: BasePart).CFrame:Inverse()
	for _, piece in tool:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.CFrame = delta * piece.CFrame
		end
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

-- Marca de bando: un brazalete en el brazo izquierdo y una capa corta a la espalda (con una banda al frente), del color del
-- equipo. Piezas pequeñas, sin colisión y soldadas al cuerpo, para que sigan las animaciones.
local function markTeam(rig: Model, team: string?)
	local info = if team then Config.Arena.Teams[team] else nil
	local torso = rig:FindFirstChild("UpperTorso")
	local arm = rig:FindFirstChild("LeftUpperArm")
	if not (info and torso and torso:IsA("BasePart")) then
		return
	end
	local function piece(name: string, size: Vector3, parent: BasePart, offset: CFrame)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = info.color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = parent.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = parent
		weld.Part1 = part
		weld.Parent = part
		part.Parent = rig
	end
	piece("TeamCape", Vector3.new(1.9, 2.1, 0.18), torso, CFrame.new(0, -0.55, 0.62))
	piece("TeamSash", Vector3.new(0.5, 1.7, 0.12), torso, CFrame.new(0, -0.2, -0.56))
	if arm and arm:IsA("BasePart") then
		piece("TeamBand", Vector3.new(1.25, 0.45, 1.25), arm, CFrame.new(0, 0.1, 0))
	end
end

-- Antorcha encendida en la mano izquierda, soldada por su agarre (como TorchService.attach). Se borra con el rig. La luz no
-- proyecta sombras (un maniquí de escena no las necesita y cuesta).
local function holdTorch(rig: Model)
	local hand = rig:FindFirstChild("LeftHand") or rig:FindFirstChild("Left Arm")
	if not (hand and hand:IsA("BasePart")) then
		warn("Actors: el maniquí no tiene mano izquierda para la antorcha")
		return
	end
	local torch = WeaponTools.buildTorch()
	torch.Name = TORCH_NAME
	torch:SetAttribute("CinematicTorch", true)
	local handle = torch.PrimaryPart :: BasePart
	-- Se mueve el modelo entero: las piezas van soldadas al Handle y se quedarían atrás si solo se moviera él.
	local offset = TORCH_HAND_OFFSET * WeaponTools.TORCH_GRIP:Inverse()
	torch:PivotTo(hand.CFrame * offset)
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = handle
	weld.C0 = offset
	weld.Parent = handle
	for _, descendant in torch:GetDescendants() do
		if descendant:IsA("Fire") then
			descendant.Enabled = true
		elseif descendant:IsA("PointLight") then
			descendant.Enabled = true
			descendant.Shadows = false
		end
	end
	torch.Parent = rig
end

-- Pone a "rig" la armadura y el arma de su rol (y la marca del bando) según "def". Devuelve el id del arma, si lleva.
local function equip(rig: Model, def: ActorDef): string?
	local role = def.role or DEFAULT_ROLE
	if def.armor or def.outfit then
		ArmorModels.wear(rig, def.armor, role, def.outfit, def.grade or ArmorModels.MAX_GRADE)
	end
	local weaponId: string? = nil
	local skin = def.skin
	if def.labWeapon then
		-- Arma del Laboratorio: WeaponTools.build toma la facción como aspecto, y el actor lleva el traje de su bando.
		weaponId = def.labWeapon
		skin = def.faction
		LabUniforms.wear(rig, def.faction)
	elseif def.weapon ~= false then
		weaponId = if typeof(def.weapon) == "string"
			then def.weapon
			else WeaponTools.roleWeapon(role, WeaponTools.MAX_LEVEL)
	end
	if weaponId then
		holdWeapon(rig, weaponId, skin)
	end
	markTeam(rig, def.team)
	if def.torch then
		holdTorch(rig)
	end
	return weaponId
end

-- Pose inicial del arma: la de apuntar del arma del Laboratorio (Aim*, en bucle) o, en las demás, WeaponCarry.
local function startWeaponPose(rig: Model, weaponId: string)
	if not animator then
		return
	end
	local labDef = LabWeapons.weapons[weaponId]
	local aimKey = if labDef then WeaponAim.AimOf[labDef.lab.pose] else nil
	if aimKey then
		animator(rig, aimKey, { t = 0, kind = "anim", action = aimKey, seconds = AIM_POSE_SECONDS })
	else
		animator(rig, "WeaponPose", { t = 0, kind = "anim", weapon = weaponId })
	end
end

local function spawnDummy(def: ActorDef, anchor: CFrame, ctx: Sequencer.Context): Model?
	local rig = baseRig(def)
	if not rig then
		return nil
	end
	table.insert(created(ctx), rig)
	local role = def.role or DEFAULT_ROLE
	rig.Name = `Cinematic_{role}`
	local weaponId = equip(rig, def)
	if def.ballGear then
		BallgameGear.build(def.ballGear, rig)
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		-- Sin arma nadie le pone el Animator (lo hace la pose del arma): los gestos y la carrera lo necesitan.
		if not humanoid:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = humanoid
		end
	end
	local ground = def.pos or Vector3.zero
	if def.snap then
		rig:SetAttribute("CinematicSnap", true)
		ground = snapToTerrain(anchor, ground)
	end
	place(rig, anchor, ground, def.yaw or 0)
	alignWeapon(rig)
	-- La raíz anclada deja el rig quieto donde se pone; los miembros siguen moviéndose con las animaciones.
	local root = rig:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
	end
	rig.Parent = Workspace
	-- Con el arma en la mano, la pose de equipada (la pone el animador del cliente; en edición no hay).
	if weaponId then
		startWeaponPose(rig, weaponId)
	end
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

-- Piezas de un rig R15: lo único que se queda de la copia del personaje (más sus Accessory: pelo, sombrero de avatar).
local R15_PARTS: { [string]: boolean } = {
	Head = true,
	UpperTorso = true,
	LowerTorso = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
	HumanoidRootPart = true,
}

-- Deja la copia del personaje solo con su cuerpo y su pelo: sin armadura ni traje del juego, arma, alas, auras ni luces
-- (el equipo del Juego de pelota lo pone BallgameGear después).
local function stripCosmetics(rig: Model)
	for _, child in rig:GetChildren() do
		if child:IsA("Model") or child:IsA("Tool") then
			child:Destroy()
		end
	end
	for _, descendant in rig:GetDescendants() do
		if descendant.Parent and descendant:IsA("BasePart") and not R15_PARTS[descendant.Name] then
			if not descendant:FindFirstAncestorOfClass("Accessory") then
				descendant:Destroy()
			end
		elseif
			descendant:IsA("ParticleEmitter")
			or descendant:IsA("Light")
			or descendant:IsA("Trail")
			or descendant:IsA("Beam")
			or descendant:IsA("Fire")
			or descendant:IsA("Smoke")
			or descendant:IsA("Sparkles")
			or descendant:IsA("Highlight")
		then
			descendant:Destroy()
		end
	end
end

-- Crea (o encuentra) el actor de "def". Devuelve nil si no se puede, con un aviso.
function Actors.spawn(def: ActorDef, anchor: CFrame, ctx: Sequencer.Context): Model?
	if def.kind == "dummy" then
		return spawnDummy(def, anchor, ctx)
	elseif def.kind == "localPlayer" then
		local player = Players.LocalPlayer
		local character = if player then player.Character else nil
		if character and def.copy then
			-- Copia con su aspecto (Dunas: el servidor devuelve al personaje real a la sala de espera en plena escena, y
			-- la copia no depende de él). El real se esconde en este cliente y se devuelve al acabar (cleanup).
			local rig = RescueCrew.cloneCharacter(character)
			if not rig then
				warn("Actors: no se pudo copiar el personaje del jugador")
				return character
			end
			table.insert(created(ctx), rig)
			rig.Name = "Cinematic_Avatar"
			stripCosmetics(rig)
			local weaponId: string? = nil
			if def.ballGear then
				BallgameGear.build(def.ballGear, rig)
			elseif def.role or def.armor or def.labWeapon then
				-- Con rol: la armadura y el arma de su rol, como un maniquí (sin trajes; el bando, con su marca).
				weaponId = equip(rig, def)
			else
				markTeam(rig, def.team)
			end
			local humanoid = rig:FindFirstChildOfClass("Humanoid")
			if humanoid and not humanoid:FindFirstChildOfClass("Animator") then
				Instance.new("Animator").Parent = humanoid
			end
			place(rig, anchor, def.pos or Vector3.zero, def.yaw or 0)
			if weaponId then
				alignWeapon(rig)
			end
			local root = rig:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				root.Anchored = true
			end
			rig.Parent = Workspace
			if weaponId then
				startWeaponPose(rig, weaponId)
			end
			local hidden: { { inst: Instance, old: number } } = {}
			for _, descendant in character:GetDescendants() do
				if descendant:IsA("BasePart") or descendant:IsA("Decal") then
					local item: any = descendant
					table.insert(hidden, { inst = descendant, old = item.LocalTransparencyModifier })
					item.LocalTransparencyModifier = 1
				end
			end
			ctx._hiddenReal = hidden
			return rig
		elseif character then
			-- El jugador es nuestro solo prestado: se anota para devolverle su sitio y quitarle las marcas al acabar, y se le
			-- pone la altura de su raíz (CinematicLift) para que un `move` lo deje de pie. snap = true: cada `move` apoya
			-- sus pies en el Terrain, como un maniquí.
			ctx._player = character
			character:SetAttribute("CinematicLift", liftOf(character))
			if def.ballGear then
				BallgameGear.build(def.ballGear, character)
				ctx._ballGearOn = character
			end
			if def.snap then
				character:SetAttribute("CinematicSnap", true)
			end
			if def.pos then
				remember(ctx, character)
				place(character, anchor, if def.snap then snapToTerrain(anchor, def.pos) else def.pos, def.yaw or 0)
			end
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

-- Reproduce una animación en un actor con el animador del place (los módulos de eventos, como LabActor, la usan).
function Actors.animate(actor: Model, action: string, event: Sequencer.Event)
	if animator then
		animator(actor, action, event)
	end
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
	local hiddenReal = ctx._hiddenReal
	if hiddenReal then
		for _, item in hiddenReal do
			if item.inst.Parent then
				pcall(function()
					(item.inst :: any).LocalTransparencyModifier = item.old
				end)
			end
		end
		ctx._hiddenReal = nil
	end
	local player = ctx._player
	if player then
		if ctx._ballGearOn then
			BallgameGear.remove(ctx._ballGearOn)
			ctx._ballGearOn = nil
		end
		player:SetAttribute("CinematicSnap", nil)
		player:SetAttribute("CinematicLift", nil)
		ctx._player = nil
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
	local pos: Vector3 = event.pos
	if actor:GetAttribute("CinematicSnap") then
		pos = snapToTerrain(anchor, pos)
	end
	-- rise (studs, opcional): altura extra sobre el suelo ya calculado; con snap, la Y de `pos` se pierde y así se hacen
	-- los saltos y los caídos (rise negativo) de las batallas.
	local target = anchor:PointToWorldSpace(pos + Vector3.new(0, lift + (event.rise or 0), 0))
	-- pitch y roll (grados, opcionales) inclinan al actor después del giro: el balanceo de un bote.
	local rotation = if event.yaw
		then (anchor * CFrame.Angles(0, math.rad(event.yaw), 0) * CFrame.Angles(
			math.rad(event.pitch or 0),
			0,
			math.rad(event.roll or 0)
		)).Rotation
		else from.Rotation
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
--   move { actor, pos, yaw?, pitch?, roll?, rise?, seconds?, easing? }  mueve el actor hasta pos (relativa al anchor);
--                                                       `rise` suma altura sobre el suelo (saltos y caídos).
function Actors.install(sequencer: typeof(Sequencer))
	sequencer.addHooks({
		start = function(scene, ctx)
			local spawned: { [string]: Model } = {}
			ctx.actors = spawned
			for name, def in scene.actors or {} do
				local model = Actors.spawn(def, ctx.anchor or CFrame.identity, ctx)
				if model then
					spawned[name] = model
					-- Los maniquíes que crea la escena se marcan como «de cinemática» (como los monos de
					-- CinematicMonkeyService): los efectos de habilidades no apoyan su rayo al suelo en ellos.
					if def.kind == "dummy" then
						model:SetAttribute("CinematicActor", name)
						CollectionService:AddTag(model, CINEMATIC_ACTOR_TAG)
					end
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
