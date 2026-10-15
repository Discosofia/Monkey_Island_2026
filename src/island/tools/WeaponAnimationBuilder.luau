--!strict
-- Generador de las animaciones de las armas a distancia (R15). Se ejecuta en Studio, en modo
-- edición (sin pulsar Play), desde la barra de comandos:
--
--   require(game.ServerStorage.Tools.WeaponAnimationBuilder).build()
--
-- Crea (o sustituye) ReplicatedStorage.WeaponAnimations con una KeyframeSequence por animación de
-- Shared/Data/WeaponAnimations: "Hold" (brazo derecho colgando con el arma, en bucle) y un disparo
-- por tipo de arma ("Stone" honda, "Arrow" arco, "Spell" bastón, "Dart" cerbatana).
-- Para probarlas basta con pulsar Play: en Studio, WeaponController usa estas secuencias mientras
-- su id esté vacío. Para el juego publicado: clic derecho en cada una > "Save to Roblox" y pegar el
-- id en Shared/Data/WeaponAnimations.
--
-- Para retocar una pose, cambia sus ángulos aquí y vuelve a ejecutar build(); después hay que
-- publicarla de nuevo (y cambiar su id). Los ángulos son en grados y en el espacio de la pieza
-- de la que cuelga cada una (joint: "raise" hacia delante/arriba, "swing" hacia la izquierda del
-- personaje). El brazo derecho extendido hacia delante son 90°.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- En Studio, require guarda el resultado de cada módulo durante toda la sesión: si el código cambia
-- después (Rojo), la barra de comandos seguiría usando la versión vieja. Una copia recién clonada
-- siempre se carga desde cero.
local function freshRequire(module: ModuleScript): any
	local copy = module:Clone()
	copy.Parent = module.Parent
	local result = require(copy) :: any
	copy:Destroy()
	return result
end

local WeaponAnimations = freshRequire(ReplicatedStorage.Shared.Data.WeaponAnimations)

local FOLDER_NAME = "WeaponAnimations"
local MARKER = "Disparo"

-- De qué pieza cuelga cada una en el rig R15 (las poses de la animación siguen esta jerarquía).
local PARENT: { [string]: string } = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
}

-- Giro hacia delante/arriba ("raise", alrededor de X) y después hacia los lados ("swing", alrededor
-- de Y; positivo hacia la izquierda del personaje), en grados.
local function joint(raise: number, swing: number?): CFrame
	return CFrame.Angles(0, math.rad(swing or 0), 0) * CFrame.Angles(math.rad(raise), 0, 0)
end

-- Brazo derecho colgando junto al cuerpo, un poco adelantado y con el codo apenas doblado.
local HOLD: { [string]: CFrame } = {
	RightUpperArm = joint(6),
	RightLowerArm = joint(10),
}

-- Las poses de disparo se escribieron sobre el brazo derecho ya extendido: para la animación se
-- les suma esa base (90° hacia delante).
local BASE: { [string]: CFrame } = {
	RightUpperArm = joint(90),
}

type Shot = {
	pose: { [string]: CFrame }, -- la pose de disparo (preparar)
	pulse: { [string]: CFrame }, -- el golpe al disparar, sobre la pose (ida y vuelta)
	seconds: number,
	raise: number, -- segundos hasta llegar a la pose
	pulseSeconds: number,
	-- El golpe empieza en el "fxDelay" de Shared/Data/WeaponAnimations (marcador "Disparo").
}

local SHOTS: { [string]: Shot } = {
	-- Honda: recoge el brazo con el codo doblado mientras la mano izquierda estira la goma hasta la
	-- cara; al soltar, el brazo se estira de golpe hacia delante y la mano izquierda sale hacia atrás.
	Stone = {
		pose = {
			RightUpperArm = joint(10, 12),
			RightLowerArm = joint(30),
			LeftUpperArm = joint(85, -45),
			LeftLowerArm = joint(95),
			Head = joint(-5),
		},
		pulse = {
			RightUpperArm = joint(-18),
			RightLowerArm = joint(-30),
			LeftUpperArm = joint(-10, 30),
		},
		seconds = 0.65,
		raise = 0.12,
		pulseSeconds = 0.18,
	},
	-- Arco: se pone de lado, alza el arco para apuntar y la mano izquierda tensa la cuerda hasta la
	-- cara; al soltar, el arco cae hacia delante, la mano izquierda sale hacia atrás y el torso gira.
	Arrow = {
		pose = {
			UpperTorso = joint(0, 20),
			Head = joint(-4, -20),
			RightUpperArm = joint(18, -20),
			LeftUpperArm = joint(85, -50),
			LeftLowerArm = joint(110),
		},
		pulse = {
			UpperTorso = joint(0, -8),
			RightUpperArm = joint(-22, 8),
			LeftUpperArm = joint(-15, 30),
		},
		seconds = 0.66,
		raise = 0.14,
		pulseSeconds = 0.2,
	},
	-- Bastón: lo alza por encima de la cabeza echándose atrás y lo lanza hacia delante con la otra
	-- mano extendida.
	Spell = {
		pose = {
			UpperTorso = joint(6),
			RightUpperArm = joint(45),
			RightLowerArm = joint(30),
			LeftUpperArm = joint(60, -15),
			LeftLowerArm = joint(20),
		},
		pulse = {
			UpperTorso = joint(-14),
			RightUpperArm = joint(-55),
			RightLowerArm = joint(-30),
			LeftUpperArm = joint(25),
		},
		seconds = 0.6,
		raise = 0.12,
		pulseSeconds = 0.18,
	},
	-- Cerbatana: dobla el codo y se la lleva a la boca, el brazo izquierdo sujeta la caña y la cabeza
	-- baja hacia ella; al soplar, la cabeza da un golpe adelante y el brazo retrocede.
	Dart = {
		pose = {
			RightUpperArm = joint(22, 28),
			RightLowerArm = joint(35),
			LeftUpperArm = joint(80, -35),
			LeftLowerArm = joint(35),
			Head = joint(-10),
		},
		pulse = {
			Head = joint(-8),
			RightUpperArm = joint(-12),
		},
		seconds = 0.55,
		raise = 0.14,
		pulseSeconds = 0.14,
	},
}

local WeaponAnimationBuilder = {}

-- Añade a "sequence" un fotograma en "time" con las piezas de "frames" (las demás de "animated",
-- en reposo). Las poses intermedias que solo dan la jerarquía llevan peso 0: no tocan esas
-- articulaciones (así se siguen moviendo las piernas al andar).
local function addKeyframe(
	sequence: KeyframeSequence,
	time: number,
	frames: { [string]: CFrame },
	animated: { [string]: boolean },
	marker: string?
)
	local keyframe = Instance.new("Keyframe")
	keyframe.Time = time
	local poses: { [string]: Pose } = {}
	local function poseOf(part: string): Pose
		local existing = poses[part]
		if existing then
			return existing
		end
		local pose = Instance.new("Pose")
		pose.Name = part
		pose.CFrame = frames[part] or CFrame.new()
		pose.Weight = if animated[part] then 1 else 0
		pose.EasingStyle = Enum.PoseEasingStyle.Cubic
		pose.EasingDirection = Enum.PoseEasingDirection.Out
		poses[part] = pose
		local parentName = PARENT[part]
		if parentName then
			poseOf(parentName):AddSubPose(pose)
		else
			keyframe:AddPose(pose)
		end
		return pose
	end
	for part in animated do
		poseOf(part)
	end
	if marker then
		local keyframeMarker = Instance.new("KeyframeMarker")
		keyframeMarker.Name = marker
		keyframe:AddMarker(keyframeMarker)
	end
	sequence:AddKeyframe(keyframe)
end

local function newSequence(name: string, priority: Enum.AnimationPriority, loop: boolean): KeyframeSequence
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Priority = priority
	sequence.Loop = loop
	return sequence
end

local function buildHold(): KeyframeSequence
	local sequence = newSequence("Hold", Enum.AnimationPriority.Action, true)
	local animated = {}
	for part in HOLD do
		animated[part] = true
	end
	addKeyframe(sequence, 0, HOLD, animated)
	addKeyframe(sequence, 1, HOLD, animated)
	return sequence
end

-- Un disparo: reposo (como Hold) → pose → golpe (ida y vuelta) → pose → reposo.
local function buildShot(name: string, shot: Shot, pulseAt: number): KeyframeSequence
	local sequence = newSequence(name, Enum.AnimationPriority.Action2, false)
	local animated: { [string]: boolean } = {}
	for _, list in { shot.pose, shot.pulse, HOLD } do
		for part in list do
			animated[part] = true
		end
	end
	local rest: { [string]: CFrame } = table.clone(HOLD)
	local posed: { [string]: CFrame } = {}
	local peak: { [string]: CFrame } = {}
	for part in animated do
		local base = BASE[part] or CFrame.new()
		local pose = shot.pose[part] or CFrame.new()
		posed[part] = pose * base
		peak[part] = pose * (shot.pulse[part] or CFrame.new()) * base
	end
	addKeyframe(sequence, 0, rest, animated)
	addKeyframe(sequence, shot.raise, posed, animated)
	addKeyframe(sequence, pulseAt, posed, animated, MARKER)
	addKeyframe(sequence, pulseAt + shot.pulseSeconds / 2, peak, animated)
	addKeyframe(sequence, pulseAt + shot.pulseSeconds, posed, animated)
	addKeyframe(sequence, shot.seconds, rest, animated)
	return sequence
end

function WeaponAnimationBuilder.build(options: { fresh: boolean? }?)
	-- Genera siempre con el código actual (ver freshRequire).
	if not (options and options.fresh) then
		freshRequire(script).build({ fresh = true })
		return
	end
	local old = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	buildHold().Parent = folder
	for name, shot in SHOTS do
		local data = WeaponAnimations[name]
		assert(data and data.fxDelay, `[WeaponAnimationBuilder] Falta "{name}" con fxDelay en Data/WeaponAnimations`)
		buildShot(name, shot, data.fxDelay).Parent = folder
	end
	folder.Parent = ReplicatedStorage
	print(
		"[WeaponAnimationBuilder] Listo: ReplicatedStorage.WeaponAnimations (Hold, Stone, Arrow, Spell, Dart).\n"
			.. "  Pruébalas con Play (en Studio se usan mientras su id esté vacío).\n"
			.. "  Para publicarlas: clic derecho en cada una > Save to Roblox, y pega cada id en\n"
			.. "  src/shared/Data/WeaponAnimations.luau (con el mismo dueño que el juego)."
	)
end

return WeaponAnimationBuilder
