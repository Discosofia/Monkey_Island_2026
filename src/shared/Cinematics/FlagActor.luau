--!strict
-- Las banderas de la cinemática de Captura la bandera (Fase 25, G10). FlagActor.install(Sequencer) registra cuatro eventos:
--   flagProp { stands }          clona en el cliente las banderas reales (Workspace.Banderas: BanderaJaguar y BanderaQuetzal,
--       de dunas/server/World/FlagModel) y las deja en su pedestal; esconde las reales solo en este cliente (transparencia
--       local, luces y carteles apagados) hasta que acaba la escena. `stands` = { Jaguar = Vector3, Quetzal = Vector3 }: el
--       suelo de cada pedestal (la base del mástil), relativo al anchor. Va primero: los demás lo necesitan. Sin
--       Workspace.Banderas no hace nada y avisa.
--   flagGrab { team, actor }     la bandera de `team` se suelda a la espalda de `actor` con el mismo desfase que
--       FlagService (CARRY_OFFSET), tela plana hacia atrás.
--   flagDrop { team, pos }       la suelta: queda quieta con la base del mástil en `pos` (relativa al anchor).
--   flagCapture { team, pos }    puntuación: la bandera de `team` vuelve a su pedestal y en `pos` (el pedestal que puntúa)
--       sale un destello (chispas y un anillo que se abre).
-- Al acabar la escena se borran las copias y se devuelven las banderas reales. Solo cliente.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Sequencer = require(script.Parent.Sequencer)

local FlagActor = {}

local FOLDER_NAME = "Banderas"
local FLAG_PREFIX = "Bandera"
local COPY_FOLDER = "CinematicFlags"
-- A la espalda: un poco por encima de los hombros, inclinada hacia un lado (igual que FlagService).
local CARRY_OFFSET = CFrame.new(0.4, 1.6, 0.75) * CFrame.Angles(0, 0, math.rad(-12))
local FLASH_COLOR = Color3.fromRGB(255, 226, 140)
local RING_SECONDS = 0.8
local RING_SIZE = 34

type Hidden = { inst: Instance, old: any }
type State = {
	folder: Folder,
	copies: { [string]: Model },
	stands: { [string]: Vector3 },
	welds: { [string]: WeldConstraint },
	hidden: { Hidden },
	temp: { Instance },
}

local function stateOf(ctx: Sequencer.Context): State?
	return ctx._flags
end

local function poleOf(copy: Model): BasePart?
	local pole = copy.PrimaryPart
	return pole
end

-- Esconde la bandera real solo en este cliente (y apunta cómo estaba). LocalTransparencyModifier no cambia lo que ven los demás.
local function hideReal(real: Model, hidden: { Hidden })
	for _, descendant in real:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(hidden, { inst = descendant, old = descendant.LocalTransparencyModifier })
			descendant.LocalTransparencyModifier = 1
		elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") or descendant:IsA("Light") then
			-- Carteles y luces: se apagan (las tres clases tienen Enabled).
			local item: any = descendant
			table.insert(hidden, { inst = descendant, old = item.Enabled })
			item.Enabled = false
		end
	end
end

local function restoreReal(hidden: { Hidden })
	for _, item in hidden do
		if item.inst.Parent then
			pcall(function()
				local inst: any = item.inst
				if inst:IsA("BasePart") then
					inst.LocalTransparencyModifier = item.old
				else
					inst.Enabled = item.old
				end
			end)
		end
	end
end

-- Quita la soldadura de la bandera (si la lleva alguien) y la deja anclada donde está.
local function release(state: State, team: string)
	local weld = state.welds[team]
	if weld then
		weld:Destroy()
		state.welds[team] = nil
	end
	local pole = if state.copies[team] then poleOf(state.copies[team]) else nil
	if pole then
		pole.Anchored = true
	end
end

-- Pone la bandera con la base del mástil en `ground` (mundo).
local function standAt(copy: Model, ground: Vector3)
	local pole = poleOf(copy)
	if not pole then
		return
	end
	copy:PivotTo(CFrame.new(ground + Vector3.new(0, pole.Size.Y / 2, 0)))
end

-- Destello de captura: chispas y un anillo plano que se abre y se desvanece.
local function flash(state: State, world: Vector3, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Name = "CinematicFlagFlash"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = world + Vector3.new(0, 1, 0)
	anchor.Parent = Workspace
	table.insert(state.temp, anchor)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(FLASH_COLOR, color)
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(0.6, 1.1)
	sparks.Speed = NumberRange.new(14, 26)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	sparks.Rate = 0
	sparks.Parent = anchor
	sparks:Emit(48)

	local ring = Instance.new("Part")
	ring.Name = "CinematicFlagRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = FLASH_COLOR
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.3, 2, 2)
	-- El cilindro de Roblox tiene su eje en X: girado, queda plano sobre el suelo.
	ring.CFrame = CFrame.new(world + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace
	table.insert(state.temp, ring)
	local tween = TweenService:Create(
		ring,
		TweenInfo.new(RING_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.3, RING_SIZE, RING_SIZE), Transparency = 1 }
	)
	tween:Play()
end

-- El estado de la escena y la copia de la bandera de `team`, o nil si no hay (sin Workspace.Banderas, o un equipo desconocido).
local function lookup(ctx: Sequencer.Context, team: any): (State?, Model?)
	local state = stateOf(ctx)
	local copy = if state and typeof(team) == "string" then state.copies[team] else nil
	if not (state and copy) then
		return nil, nil
	end
	return state, copy
end

function FlagActor.install(sequencer: typeof(Sequencer))
	sequencer.registerHandler("flagProp", function(event: Sequencer.Event, ctx: Sequencer.Context)
		if ctx._flags then
			return -- un seek hacia atrás repite el evento: las copias ya están
		end
		local source = Workspace:FindFirstChild(FOLDER_NAME)
		if not source then
			warn("FlagActor: no existe Workspace.Banderas; la escena sigue sin banderas")
			return
		end
		local anchor: CFrame = ctx.anchor or CFrame.identity
		local folder = Instance.new("Folder")
		folder.Name = COPY_FOLDER
		folder.Parent = Workspace
		local state: State = { folder = folder, copies = {}, stands = {}, welds = {}, hidden = {}, temp = {} }
		ctx._flags = state
		local stands: { [string]: Vector3 } = event.stands or {}
		for team, ground in stands do
			state.stands[team] = ground
			local real = source:FindFirstChild(`{FLAG_PREFIX}{team}`)
			if real and real:IsA("Model") then
				local copy = real:Clone()
				copy.Name = `Cinematic{FLAG_PREFIX}{team}`
				-- El icono sobre la bandera (que se ve a través de las paredes) no pinta nada en la escena.
				local marker = copy:FindFirstChild("Marker", true)
				if marker then
					marker:Destroy()
				end
				local pole = poleOf(copy)
				if pole then
					pole.Anchored = true
				end
				standAt(copy, anchor:PointToWorldSpace(ground))
				copy.Parent = folder
				state.copies[team] = copy
				hideReal(real, state.hidden)
			else
				warn(`FlagActor: no existe la bandera {FLAG_PREFIX}{team} en Workspace.Banderas`)
			end
		end
	end)

	sequencer.registerHandler("flagGrab", function(event: Sequencer.Event, ctx: Sequencer.Context)
		local state, copy = lookup(ctx, event.team)
		if not (state and copy) then
			return
		end
		local actor = if ctx.actors then ctx.actors[event.actor] else nil
		local torso = if actor then (actor :: Model):FindFirstChild("UpperTorso") else nil
		local pole = poleOf(copy)
		if not (torso and torso:IsA("BasePart") and pole) then
			warn(`FlagActor: flagGrab sin actor o sin torso ({event.actor})`)
			return
		end
		release(state, event.team)
		pole.Anchored = false
		copy:PivotTo(torso.CFrame * CARRY_OFFSET)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = pole
		weld.Parent = pole
		state.welds[event.team] = weld
	end)

	sequencer.registerHandler("flagDrop", function(event: Sequencer.Event, ctx: Sequencer.Context)
		local state, copy = lookup(ctx, event.team)
		if not (state and copy) then
			return
		end
		release(state, event.team)
		local anchor: CFrame = ctx.anchor or CFrame.identity
		standAt(copy, anchor:PointToWorldSpace(event.pos))
	end)

	sequencer.registerHandler("flagCapture", function(event: Sequencer.Event, ctx: Sequencer.Context)
		local state, copy = lookup(ctx, event.team)
		if not (state and copy) then
			return
		end
		release(state, event.team)
		local anchor: CFrame = ctx.anchor or CFrame.identity
		local home = state.stands[event.team]
		if home then
			standAt(copy, anchor:PointToWorldSpace(home))
		end
		if ctx.seeking then
			return
		end
		local cloth = copy:FindFirstChild("Cloth")
		local color = if cloth and cloth:IsA("BasePart") then cloth.Color else FLASH_COLOR
		flash(state, anchor:PointToWorldSpace(event.pos or Vector3.zero), color)
	end)

	sequencer.addHooks({
		finish = function(_, ctx)
			local state = stateOf(ctx)
			if not state then
				return
			end
			for _, weld in state.welds do
				weld:Destroy()
			end
			for _, item in state.temp do
				item:Destroy()
			end
			state.folder:Destroy()
			restoreReal(state.hidden)
			ctx._flags = nil
		end,
	})
end

return FlagActor
