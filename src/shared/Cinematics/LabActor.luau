--!strict
-- Eventos del Laboratorio en ruinas para las cinemáticas (Fase 25, G12). LabActor.install(Sequencer) registra:
--   labShot { actor, target?, speed?, range?, weapon? }   el actor dispara su arma del Laboratorio (Actors: labWeapon):
--       reproduce su pose de disparo (anim con lab.pose) y, un fxDelay después, sale el proyectil real de la boca del
--       arma (AbilityFxController "Projectile", con la gravedad y el frenado de Ballistics), el fogonazo ("LabMuzzle") y
--       el sonido del arma. `target` = Vector3 relativo al anchor o id de otro actor; sin él, hacia donde mira el actor.
--       `speed` y `range` por defecto los del arma (el alcance se recorta a la distancia al blanco).
--       Si el actor es el de la vista (fpView), sale de la boca del arma de la vista.
--   labLight { map }                                        pone la luz de un mapa del Laboratorio (Shared/LabLighting).
--       Al acabar la escena vuelve la del mapa de la partida (Workspace.LabMap, atributo Map).
--   fpView { on, actor?, weapon?, faction?, skin?, target?, fov? }   primera persona de un actor: con on, la cámara pasa a
--       su cabeza (mirando a `target` o hacia delante) y se monta el arma con los brazos (CombatClient/LabViewBuilder);
--       con on = false, o al acabar, se quita. Mientras dura, el jugador tiene el atributo CinematicActive para que
--       FirstPersonController no dibuje su propia vista.
--   fpAnim { key, seconds?, weight? }                       una pista de la vista (Fire, Reload, Equip; Aim con `weight`).
-- Solo cliente. Necesita CombatClient (AbilityFxController y LabViewBuilder): se cargan al usarse, sin ellos solo avisa.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Actors = require(script.Parent.Actors)
local Ballistics = require(script.Parent.Parent.Ballistics)
local Config = require(script.Parent.Parent.Config)
local LabLighting = require(script.Parent.Parent.LabLighting)
local LabWeapons = require(script.Parent.Parent.Data.LabWeapons)
local Sequencer = require(script.Parent.Sequencer)
local Sfx = require(script.Parent.Parent.Sfx)
local WeaponAnimations = require(script.Parent.Parent.Data.WeaponAnimations)

local LabActor = {}

local DEFAULT_FOV = 70
local EYE_LIFT = 0.2 -- studs sobre el centro de la cabeza
local CHEST_LIFT = 0.5 -- el blanco de un disparo a otro actor: el torso, un poco alto
local ACTIVE_ATTRIBUTE = "CinematicActive"
local FACTIONS = { Guardians = true, Pirates = true }

type Hidden = { inst: BasePart, old: number }
type FirstPerson = {
	actor: Model,
	view: any, -- LabViewBuilder.View
	hook: (t: number) -> (),
	hidden: { Hidden },
	target: any,
	fov: number,
	weaponId: string,
}
type State = { fp: FirstPerson?, light: boolean }

-- Un módulo de CombatClient (AbilityFxController, LabViewBuilder), o nil si el place no lo tiene.
local cached: { [string]: any } = {}
local function combatModule(name: string): any?
	if cached[name] ~= nil then
		return cached[name]
	end
	local folder = ReplicatedStorage:FindFirstChild("CombatClient")
	local module = if folder then folder:FindFirstChild(name, true) else nil
	if not (module and module:IsA("ModuleScript")) then
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok then
		warn(`LabActor: no se pudo cargar {name}: {result}`)
		return nil
	end
	cached[name] = result
	return result
end

local function stateOf(ctx: Sequencer.Context): State
	local state = ctx._lab
	if not state then
		state = { fp = nil, light = false }
		ctx._lab = state
	end
	return state
end

local function anchorOf(ctx: Sequencer.Context): CFrame
	return ctx.anchor or CFrame.identity
end

local function actorOf(event: Sequencer.Event, ctx: Sequencer.Context): Model?
	local actors = ctx.actors
	local actor = if actors and event.actor then actors[event.actor] else nil
	if not actor then
		warn(`LabActor: el evento {event.kind} pide un actor que no existe ({event.actor})`)
	end
	return actor
end

-- El arma del Laboratorio que lleva el actor (su Tool): id, mango y boca (Attachment/pieza "Muzzle" o el mango).
local function weaponOf(actor: Model): (string?, BasePart?, Instance?)
	local tool = actor:FindFirstChildOfClass("Tool")
	if not tool then
		return nil, nil, nil
	end
	local id = tool:GetAttribute("WeaponId")
	local handle = tool:FindFirstChild("Handle")
	local muzzle = tool:FindFirstChild("Muzzle", true)
	return if typeof(id) == "string" then id else nil, if handle and handle:IsA("BasePart") then handle else nil, muzzle
end

local function positionOf(inst: Instance?): Vector3?
	if inst and inst:IsA("Attachment") then
		return inst.WorldPosition
	elseif inst and inst:IsA("BasePart") then
		return inst.Position
	end
	return nil
end

-- La pieza que lleva la boca (para el fogonazo): la propia pieza o la que sostiene el Attachment.
local function partOf(inst: Instance?): BasePart?
	if inst and inst:IsA("BasePart") then
		return inst
	elseif inst and inst:IsA("Attachment") and inst.Parent and inst.Parent:IsA("BasePart") then
		return inst.Parent
	end
	return nil
end

-- El punto del mundo al que apunta un evento (`target`: Vector3 relativo al anchor o id de actor), o nil.
local function targetPoint(target: any, ctx: Sequencer.Context): Vector3?
	if typeof(target) == "Vector3" then
		return anchorOf(ctx):PointToWorldSpace(target)
	elseif typeof(target) == "string" then
		local other = if ctx.actors then ctx.actors[target] else nil
		local torso = if other then (other :: Model):FindFirstChild("UpperTorso") else nil
		if torso and torso:IsA("BasePart") then
			return torso.Position + Vector3.new(0, CHEST_LIFT, 0)
		end
	end
	return nil
end

-- El disparo en sí: proyectil, fogonazo y sonido. Se llama ya con el fxDelay pasado.
local function fireEffects(
	actor: Model,
	weaponId: string,
	event: Sequencer.Event,
	ctx: Sequencer.Context,
	handle: Sequencer.Handle
)
	if not handle.isPlaying() or not actor.Parent then
		return
	end
	local weapon = LabWeapons.weapons[weaponId]
	local fx = combatModule("AbilityFxController")
	local _, toolHandle, toolMuzzle = weaponOf(actor)
	if not (weapon and fx and toolHandle) then
		return
	end
	local state = stateOf(ctx)
	local fp = state.fp
	local fromView = fp ~= nil and fp.actor == actor
	-- De la boca del arma de la vista si el actor es el de la primera persona; si no, de la de su mano.
	local muzzleInst: Instance? = if fromView and fp then fp.view.viewMuzzle else (toolMuzzle or toolHandle)
	local origin = positionOf(muzzleInst) or toolHandle.Position
	local aimed = targetPoint(event.target, ctx)
	local forward: Vector3
	if aimed then
		forward = aimed - origin
	elseif fromView and Workspace.CurrentCamera then
		forward = Workspace.CurrentCamera.CFrame.LookVector
	else
		local root = actor:FindFirstChild("HumanoidRootPart")
		forward = if root and root:IsA("BasePart") then root.CFrame.LookVector else toolHandle.CFrame.LookVector
	end
	if forward.Magnitude < 1e-3 then
		return
	end
	local speed: number = event.speed or weapon.projectileSpeed
	local weaponRange: number = weapon.range
	local range: number = event.range or (if aimed then math.min(weaponRange, forward.Magnitude) else weaponRange)
	-- Gravedad y frenado como en el juego (WeaponController.launchLocalShot); la caída se compensa al apuntar.
	local motion = Ballistics.motion(Ballistics.profile(weaponId, weapon.projectile), speed, weaponRange)
	local direction = if aimed then Ballistics.launchFor(origin, aimed, motion) else forward.Unit
	fx.play(
		"Projectile",
		nil,
		weapon.projectile,
		actor,
		origin,
		direction,
		speed,
		range,
		Workspace:GetServerTimeNow(),
		false,
		nil,
		if motion and motion.gravity > 0 then motion.gravity else nil,
		if motion and motion.drag > 0 then motion.drag else nil
	)
	local flash = partOf(muzzleInst)
	if flash then
		fx.play("LabMuzzle", flash, weapon.projectile)
	end
	Sfx.play(weapon.sound, toolHandle)
end

local function paintHidden(actor: Model, hidden: { Hidden })
	for _, descendant in actor:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(hidden, { inst = descendant, old = descendant.LocalTransparencyModifier })
			descendant.LocalTransparencyModifier = 1
		end
	end
end

local function restoreHidden(hidden: { Hidden })
	for _, item in hidden do
		if item.inst.Parent then
			item.inst.LocalTransparencyModifier = item.old
		end
	end
end

-- Quita la primera persona de la escena: la vista y la función por cuadro. "final" (al acabar la escena) quita además
-- el atributo CinematicActive; en mitad de la escena se queda puesto, para que la vista del propio jugador
-- (FirstPersonController) siga apagada también en los planos en tercera persona (lo pone LabCineController).
local function stopFirstPerson(ctx: Sequencer.Context, final: boolean?)
	local state = stateOf(ctx)
	local fp = state.fp
	if not fp then
		return
	end
	state.fp = nil
	local hooks = ctx.frameHooks
	if hooks then
		local index = table.find(hooks, fp.hook)
		if index then
			table.remove(hooks, index)
		end
	end
	fp.view.rig.model:Destroy()
	restoreHidden(fp.hidden)
	local player = Players.LocalPlayer
	if player and final then
		player:SetAttribute(ACTIVE_ATTRIBUTE, nil)
	end
end

local function startFirstPerson(event: Sequencer.Event, ctx: Sequencer.Context)
	local state = stateOf(ctx)
	if state.fp then
		return -- un seek hacia atrás repite el evento: la vista ya está
	end
	local actor = actorOf(event, ctx)
	local builder = combatModule("LabViewBuilder")
	local camera = Workspace.CurrentCamera
	if not (actor and builder and camera) then
		warn("LabActor: fpView sin actor, sin CombatClient/LabViewBuilder o sin cámara")
		return
	end
	local actorWeapon = weaponOf(actor)
	local weaponId: string? = event.weapon or actorWeapon
	if not weaponId then
		warn("LabActor: fpView sin arma (el actor no lleva una y el evento no trae `weapon`)")
		return
	end
	local faction = if FACTIONS[event.faction] then event.faction else "Guardians"
	local hand = actor:FindFirstChild("RightHand")
	local skinColor = if hand and hand:IsA("BasePart") then hand.Color else Color3.fromRGB(205, 160, 120)
	local view = builder.build(weaponId, faction, event.skin, skinColor, camera)
	local rig = view.rig
	local fov: number = event.fov or DEFAULT_FOV
	local head = actor:FindFirstChild("Head")
	local root = actor:FindFirstChild("HumanoidRootPart")

	-- Tras colocar la cámara de la escena: la cámara en la cabeza del actor y el rig delante de ella.
	local function place(_t: number)
		if not (head and head:IsA("BasePart") and actor.Parent) then
			return
		end
		local eye = head.Position + Vector3.new(0, EYE_LIFT, 0)
		local aimed = targetPoint(event.target, ctx)
		local direction = if aimed and (aimed - eye).Magnitude > 1e-3
			then (aimed - eye).Unit
			elseif root and root:IsA("BasePart") then root.CFrame.LookVector
			else head.CFrame.LookVector
		camera.CFrame = CFrame.lookAt(eye, eye + direction)
		camera.FieldOfView = fov
		rig.root.CFrame = camera.CFrame
			* CFrame.new(builder.HIP_OFFSET)
			* CFrame.Angles(builder.HIP_PITCH, builder.HIP_YAW, 0)
	end
	local hidden: { Hidden } = {}
	paintHidden(actor, hidden)
	local hooks = ctx.frameHooks
	if not hooks then
		hooks = {}
		ctx.frameHooks = hooks
	end
	table.insert(hooks, place)
	state.fp = {
		actor = actor,
		view = view,
		hook = place,
		hidden = hidden,
		target = event.target,
		fov = fov,
		weaponId = weaponId,
	}
	local player = Players.LocalPlayer
	if player then
		player:SetAttribute(ACTIVE_ATTRIBUTE, true)
	end
	-- Como FirstPersonController: la pista Aim parada en su primer fotograma (la mira no se mueve) y Equip al sacarla.
	local aim = view.tracks.Aim
	if aim then
		aim:Play(0, 0.001)
		aim:AdjustSpeed(0)
	end
	local equip = view.tracks.Equip
	if equip then
		equip:Play(0)
	end
	place(0)
end

-- Vuelve a poner la luz del mapa de la partida (Workspace.LabMap, atributo Map; si no, el del estudio).
function LabActor.restoreMapLighting()
	local folder = Workspace:FindFirstChild("LabMap")
	local mapId = if folder then folder:GetAttribute("Map") else nil
	local preset = LabLighting.presets[if typeof(mapId) == "string" then mapId else Config.Lab.StudioMap]
	if preset then
		LabLighting.apply(preset)
	end
end

function LabActor.install(sequencer: typeof(Sequencer))
	sequencer.registerHandler("labShot", function(event: Sequencer.Event, ctx: Sequencer.Context, handle)
		if ctx.seeking then
			return
		end
		local actor = actorOf(event, ctx)
		if not actor then
			return
		end
		local actorWeapon = weaponOf(actor)
		local weaponId: string? = event.weapon or actorWeapon
		local weapon = if weaponId then LabWeapons.weapons[weaponId] else nil
		if not (weaponId and weapon) then
			warn(`LabActor: labShot de un actor sin arma del Laboratorio ({event.actor})`)
			return
		end
		-- Por detrás, el actor reproduce su disparo; los efectos salen en su marcador "Disparo" (fxDelay).
		local pose = weapon.lab.pose
		local shot = (WeaponAnimations :: any)[pose]
		Actors.animate(actor, pose, { t = event.t, kind = "anim", action = pose })
		local delay: number = if shot and shot.fxDelay then shot.fxDelay else 0
		local id = weaponId
		task.delay(delay, function()
			fireEffects(actor, id, event, ctx, handle)
		end)
	end)

	sequencer.registerHandler("labLight", function(event: Sequencer.Event, ctx: Sequencer.Context)
		local preset = LabLighting.presets[event.map]
		if not preset then
			warn(`LabActor: labLight con un mapa desconocido ({event.map})`)
			return
		end
		stateOf(ctx).light = true
		LabLighting.apply(preset)
	end)

	sequencer.registerHandler("fpView", function(event: Sequencer.Event, ctx: Sequencer.Context)
		if event.on == false then
			stopFirstPerson(ctx)
		else
			startFirstPerson(event, ctx)
		end
	end)

	sequencer.registerHandler("fpAnim", function(event: Sequencer.Event, ctx: Sequencer.Context)
		if ctx.seeking then
			return
		end
		local fp = stateOf(ctx).fp
		local track = if fp then fp.view.tracks[event.key] else nil
		if not (fp and track) then
			return
		end
		if event.key == "Aim" then
			-- Apuntar: el peso es el acercado (0 = cadera), como en FirstPersonController.
			track:AdjustWeight(math.max(event.weight or 0, 0.001))
		elseif event.key == "Fire" then
			if track.IsPlaying then
				track:Stop(0)
			end
			local weapon = LabWeapons.weapons[fp.weaponId]
			local cooldown = if weapon then weapon.cooldownSeconds else 1
			local speed = if track.Length > cooldown then track.Length / cooldown else 1
			track:Play(0.02, 1, speed)
		elseif event.key == "Reload" then
			local weapon = LabWeapons.weapons[fp.weaponId]
			local seconds: number = event.seconds or (if weapon then weapon.lab.reloadSeconds else 2)
			local length = if track.Length > 0 then track.Length else seconds
			track:Play(0.1, 1, length / math.max(seconds, 0.05))
		else
			track:Play(0.1)
		end
	end)

	sequencer.addHooks({
		finish = function(_, ctx)
			local state = ctx._lab
			if not state then
				return
			end
			stopFirstPerson(ctx, true)
			if state.light then
				LabActor.restoreMapLighting()
			end
			ctx._lab = nil
		end,
	})
end

return LabActor
