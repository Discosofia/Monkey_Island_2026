--!strict
-- Tripulación del helicóptero de rescate (Fase 25, G3b). Solo cliente; sin Remotes, Settings ni CombatClient.
-- RescueCrew.install(Sequencer) registra el evento crewBoard (sin parámetros) y un hook de fin:
--   crewBoard  sienta en el helicóptero (ctx.actors.heli) a un piloto con mono naranja y casco y, como pasajeros, a
--              una copia pequeña del personaje de cada jugador (los que caben en HelicopterModel.SEATS; el jugador
--              local, el primero y el más cerca de la puerta). Quedan sentados, quietos y soldados al "Body", y cada
--              pasajero saluda con el brazo derecho. Los personajes reales de TODOS los jugadores se ocultan solo en
--              este cliente (LocalTransparencyModifier) para que no se vean además en su sitio.
--   fin        borra la tripulación, desconecta el saludo y devuelve la visibilidad a los personajes, aunque la
--              escena se salte o se pare.
-- Ejes de las poses (el rig R15 mira a -Z y la derecha del personaje es +X): una rotación X de +90° sobre una pieza que
-- cuelga hacia -Y la lleva a -Z (hacia delante). Por eso la cadera se gira +90° (muslo hacia delante), la rodilla -90°
-- (pantorrilla otra vez hacia abajo) y el hombro del piloto +80° (brazo casi horizontal hacia delante). El saludo gira
-- el hombro derecho en Z: 155° es brazo arriba y un poco hacia fuera (+X).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HelicopterModel = require(script.Parent.Parent.HelicopterModel)
local Sequencer = require(script.Parent.Sequencer)

local RescueCrew = {}

local CREW_SCALE = 0.42 -- los rigs caben en la cabina (alto de 2,2)
local HIP_ANGLE = math.rad(90)
local KNEE_ANGLE = math.rad(-90)
local PILOT_ARM_ANGLE = math.rad(80)
local WAVE_BASE = math.rad(155)
local WAVE_RANGE = math.rad(25)
local WAVE_HZ = 3
local TEMPLATE_NAME = "CinematicDummy"

local SUIT = Color3.fromRGB(232, 106, 23)
local PANTS = Color3.fromRGB(60, 62, 66)
local SKIN = Color3.fromRGB(255, 204, 153)
local HELMET = Color3.fromRGB(240, 240, 235)
local VISOR = Color3.fromRGB(120, 200, 230)
local BLACK = Color3.fromRGB(20, 20, 22)

type Hidden = { inst: Instance, old: number }
type Waver = { motor: Motor6D, phase: number }
type Crew = {
	models: { Model },
	hidden: { Hidden },
	wavers: { Waver },
	connection: RBXScriptConnection?,
}

-- Medidas del rig R15 ya escalado, en el marco de su HumanoidRootPart (nil si no es R15 completo).
type Measure = { hip: Vector3, shoulder: Vector3, thigh: number, reach: number }

local function motorOf(rig: Model, name: string): Motor6D?
	local motor = rig:FindFirstChild(name, true)
	if motor and motor:IsA("Motor6D") then
		return motor
	end
	return nil
end

-- Los personajes de los jugadores en Roblox actual unen sus piezas con AnimationConstraint (las mueve el Animator y
-- la física), que no sirven para una postura estática soldada a un helicóptero. Se cambian por Motor6D con las
-- mismas piezas y marcos, de nombre igual (Root, Waist, RightHip…), y la postura se pone con Transform.
local function toMotors(rig: Model)
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("AnimationConstraint") then
			local motor = Instance.new("Motor6D")
			motor.Name = descendant.Name
			motor.Part0 = descendant.Part0
			motor.Part1 = descendant.Part1
			motor.C0 = descendant.C0
			motor.C1 = descendant.C1
			motor.Parent = descendant.Parent
			descendant:Destroy()
		end
	end
end

-- Posición de reposo de la pieza 1 respecto a la pieza 0 de una articulación.
local function restFrame(motor: Motor6D): CFrame
	return motor.C0 * motor.C1:Inverse()
end

local function measure(rig: Model): Measure?
	-- En R15 la unión de la raíz con LowerTorso se llama "Root" ("RootJoint" es de R6).
	local rootJoint, waist = motorOf(rig, "Root") or motorOf(rig, "RootJoint"), motorOf(rig, "Waist")
	local hip, shoulder = motorOf(rig, "RightHip"), motorOf(rig, "RightShoulder")
	local leg, arm = rig:FindFirstChild("RightUpperLeg"), rig:FindFirstChild("RightUpperArm")
	local forearm, hand = rig:FindFirstChild("RightLowerArm"), rig:FindFirstChild("RightHand")
	if not (rootJoint and waist and hip and shoulder) then
		return nil
	end
	if not (leg and leg:IsA("BasePart") and arm and arm:IsA("BasePart")) then
		return nil
	end
	if not (forearm and forearm:IsA("BasePart") and hand and hand:IsA("BasePart")) then
		return nil
	end
	local rootToLower = restFrame(rootJoint)
	local rootToUpper = rootToLower * restFrame(waist)
	return {
		hip = (rootToLower * hip.C0).Position,
		shoulder = (rootToUpper * shoulder.C0).Position,
		thigh = math.min(leg.Size.X, leg.Size.Z),
		reach = arm.Size.Y + forearm.Size.Y + hand.Size.Y / 2,
	}
end

-- Una pieza suelta de la tripulación (volante, casco…): sin colisión y soldada a "anchor".
local function addPart(
	parent: Instance,
	anchor: BasePart,
	name: string,
	size: Vector3,
	color: Color3,
	offset: CFrame
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = anchor.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = parent
	return part
end

-- Deja el rig quieto y sin colisiones, listo para soldarlo.
local function freeze(rig: Model)
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.LocalTransparencyModifier = 0
		end
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.PlatformStand = true
		pcall(function()
			humanoid.EvaluateStateMachine = false
		end)
	end
end

-- Sienta "rig" (con su HumanoidRootPart) en la plaza "seatPos" del helicóptero: cadera sobre el cojín, mirando a -Z,
-- con las piernas dobladas. Devuelve las medidas del rig (para el volante del piloto).
local function sit(rig: Model, body: BasePart, seatPos: Vector3): Measure?
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	rig.PrimaryPart = root
	local info = measure(rig)
	local rootPos: Vector3
	if info then
		-- El muslo horizontal descansa sobre el cojín: su cara de abajo está a media grosor bajo la cadera.
		rootPos = Vector3.new(seatPos.X - info.hip.X, seatPos.Y - (info.hip.Y - info.thigh / 2), seatPos.Z - info.hip.Z)
		for name, angle in { RightHip = HIP_ANGLE, LeftHip = HIP_ANGLE, RightKnee = KNEE_ANGLE, LeftKnee = KNEE_ANGLE } do
			local motor = motorOf(rig, name)
			if motor then
				motor.Transform = CFrame.Angles(angle, 0, 0)
			end
		end
	else
		-- Sin un R15 completo no hay postura: se deja de pie sobre el cojín, que es mejor que nada.
		rootPos = seatPos + Vector3.new(0, root.Size.Y / 2 + 0.2, 0)
	end
	local seatCFrame = CFrame.new(rootPos)
	rig:PivotTo(body.CFrame * seatCFrame)
	local weld = Instance.new("Weld")
	weld.Name = "SeatWeld"
	weld.Part0 = body
	weld.Part1 = root
	weld.C0 = seatCFrame
	weld.Parent = root
	return info
end

-- Piloto: rig R15 con mono naranja, piernas grises y casco blanco con visera de cristal y un auricular.
local function recolorPilot(rig: Model)
	local colors: { [string]: Color3 } = {
		Head = SKIN,
		UpperTorso = SUIT,
		LowerTorso = SUIT,
		LeftUpperArm = SUIT,
		RightUpperArm = SUIT,
		LeftLowerArm = SUIT,
		RightLowerArm = SUIT,
		LeftHand = SKIN,
		RightHand = SKIN,
		LeftUpperLeg = PANTS,
		RightUpperLeg = PANTS,
		LeftLowerLeg = PANTS,
		RightLowerLeg = PANTS,
		LeftFoot = PANTS,
		RightFoot = PANTS,
	}
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			local color = colors[descendant.Name]
			if color then
				descendant.Color = color
			end
		elseif descendant:IsA("Accessory") or descendant:IsA("Clothing") then
			descendant:Destroy()
		end
	end
end

local function buildHelmet(rig: Model)
	local head = rig:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local s = head.Size
	addPart(
		rig,
		head,
		"HelmetShell",
		Vector3.new(s.X * 1.15, s.Y * 0.62, s.Z * 1.15),
		HELMET,
		CFrame.new(0, s.Y * 0.28, 0)
	)
	local visor = addPart(
		rig,
		head,
		"HelmetVisor",
		Vector3.new(s.X * 0.95, s.Y * 0.3, s.Z * 0.05),
		VISOR,
		CFrame.new(0, s.Y * 0.1, -s.Z * 0.6)
	)
	visor.Transparency = 0.25
	addPart(
		rig,
		head,
		"HelmetEarpiece",
		Vector3.new(s.X * 0.1, s.Y * 0.3, s.Z * 0.3),
		BLACK,
		CFrame.new(s.X * 0.58, 0, 0)
	)
end

local function newPilotRig(): Model?
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if ok and rig then
		return rig :: Model
	end
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local template = if shared then shared:FindFirstChild(TEMPLATE_NAME) else nil
	if template and template:IsA("Model") then
		return template:Clone()
	end
	warn("RescueCrew: no se puede crear el piloto R15 aquí")
	return nil
end

local function addPilot(crew: Crew, heli: Model, body: BasePart)
	local rig = newPilotRig()
	if rig then
		toMotors(rig)
	end
	if not rig then
		return
	end
	rig.Name = "RescuePilot"
	rig:ScaleTo(CREW_SCALE)
	recolorPilot(rig)
	freeze(rig)
	local seat = HelicopterModel.PILOT_SEAT
	local info = sit(rig, body, seat)
	buildHelmet(rig)
	if info then
		-- Ambos brazos al frente y, a la altura de las manos, un volante: barra con su columna.
		for _, name in { "RightShoulder", "LeftShoulder" } do
			local motor = motorOf(rig, name)
			if motor then
				motor.Transform = CFrame.Angles(PILOT_ARM_ANGLE, 0, 0)
			end
		end
		local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
		local rootPos = body.CFrame:ToObjectSpace(root.CFrame).Position
		local hands = rootPos
			+ Vector3.new(
				0,
				info.shoulder.Y - math.cos(PILOT_ARM_ANGLE) * info.reach,
				info.shoulder.Z - math.sin(PILOT_ARM_ANGLE) * info.reach
			)
		local width = math.abs(info.shoulder.X) * 2 + 0.2
		addPart(rig, body, "YokeBar", Vector3.new(width, 0.12, 0.12), PANTS, CFrame.new(hands))
		addPart(
			rig,
			body,
			"YokeColumn",
			Vector3.new(0.12, 0.5, 0.12),
			PANTS,
			CFrame.new(hands - Vector3.new(0, 0.3, 0))
		)
	end
	rig.Parent = heli
	table.insert(crew.models, rig)
end

-- Copia pequeña y sin scripts del personaje de "player", sentada en "seatPos". Devuelve false si no se pudo.
local function addPassenger(
	crew: Crew,
	heli: Model,
	body: BasePart,
	character: Model,
	seatPos: Vector3,
	index: number
): boolean
	local clone: Model? = nil
	pcall(function()
		local wasArchivable = character.Archivable
		character.Archivable = true
		clone = character:Clone()
		character.Archivable = wasArchivable
	end)
	if not clone then
		return false
	end
	local rig = clone :: Model
	rig.Name = "RescuePassenger"
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("Tool") or descendant:IsA("ForceField") then
			descendant:Destroy()
		end
	end
	toMotors(rig)
	if not pcall(rig.ScaleTo, rig, CREW_SCALE) then
		rig:Destroy()
		return false
	end
	freeze(rig)
	-- sit devuelve nil tanto sin HumanoidRootPart como con un rig que no se puede medir (un personaje con otro
	-- esqueleto sube igualmente, de pie sobre el cojín): solo falla si no hay raíz que soldar.
	sit(rig, body, seatPos)
	if not rig:FindFirstChild("HumanoidRootPart") then
		rig:Destroy()
		return false
	end
	local shoulder = motorOf(rig, "RightShoulder")
	if shoulder then
		table.insert(crew.wavers, { motor = shoulder, phase = index * 0.9 })
	end
	rig.Parent = heli
	table.insert(crew.models, rig)
	return true
end

local function hideCharacter(crew: Crew, character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			local item: any = descendant
			table.insert(crew.hidden, { inst = descendant, old = item.LocalTransparencyModifier })
			item.LocalTransparencyModifier = 1
		end
	end
end

-- Quita la tripulación y devuelve lo que ocultó. No falla si ya no hay nada.
function RescueCrew.clear(ctx: Sequencer.Context)
	local crew: Crew? = ctx._crew
	if not crew then
		return
	end
	ctx._crew = nil
	if crew.connection then
		crew.connection:Disconnect()
		crew.connection = nil
	end
	for _, hidden in crew.hidden do
		if hidden.inst.Parent then
			pcall(function()
				(hidden.inst :: any).LocalTransparencyModifier = hidden.old
			end)
		end
	end
	for _, model in crew.models do
		model:Destroy()
	end
end

local function board(ctx: Sequencer.Context)
	RescueCrew.clear(ctx)
	local actors = ctx.actors
	local heli = if actors then actors.heli else nil
	local body = if heli and heli:IsA("Model") then heli.PrimaryPart else nil
	if not (heli and body) then
		warn("RescueCrew: no hay helicóptero (ctx.actors.heli)")
		return
	end
	local crew: Crew = { models = {}, hidden = {}, wavers = {}, connection = nil }
	ctx._crew = crew

	addPilot(crew, heli, body)

	-- El jugador local, el primero (la plaza más cerca de la puerta); los demás, en el orden de Players.
	local players: { Player } = {}
	for _, player in Players:GetPlayers() do
		if player == Players.LocalPlayer then
			table.insert(players, 1, player)
		else
			table.insert(players, player)
		end
	end
	local seats = HelicopterModel.SEATS
	local taken = 0
	for _, player in players do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if character and humanoid and humanoid.Health > 0 and taken < #seats then
			if addPassenger(crew, heli, body, character, seats[taken + 1], taken) then
				taken += 1
			end
		end
	end

	-- Con las copias ya hechas, se oculta a todos los jugadores reales (también a los que no caben).
	for _, player in players do
		if player.Character then
			hideCharacter(crew, player.Character)
		end
	end

	if #crew.wavers > 0 then
		crew.connection = RunService.PreRender:Connect(function()
			local t = os.clock() * math.pi * 2 * WAVE_HZ
			for _, waver in crew.wavers do
				if waver.motor.Parent then
					waver.motor.Transform = CFrame.Angles(0, 0, WAVE_BASE + math.sin(t + waver.phase) * WAVE_RANGE)
				end
			end
		end)
		heli.Destroying:Connect(function()
			if crew.connection then
				crew.connection:Disconnect()
				crew.connection = nil
			end
		end)
	end
end

function RescueCrew.install(sequencer: typeof(Sequencer))
	sequencer.registerHandler("crewBoard", function(_, ctx)
		board(ctx)
	end)
	sequencer.addHooks({
		finish = function(_, ctx)
			RescueCrew.clear(ctx)
		end,
	})
end

return RescueCrew
