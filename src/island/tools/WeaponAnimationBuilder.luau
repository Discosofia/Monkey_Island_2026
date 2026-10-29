--!strict
-- Generador de las animaciones de las armas (R15). Se ejecuta en Studio, en modo edición (sin pulsar
-- Play), desde la barra de comandos:
--
--   require(game.ServerStorage.Tools.WeaponAnimationBuilder).build()
--
-- Crea (o sustituye) ReplicatedStorage.WeaponAnimations con una KeyframeSequence por animación de
-- Shared/Data/WeaponAnimations: "Hold" (brazo derecho colgando con el arma, en bucle), un disparo
-- por tipo de arma ("Stone" honda, "Arrow" arco, "Spell" bastón, "Dart" cerbatana; y las del Laboratorio,
-- "LabRifle", "LabHarpoon" y "LabCannon", Fase 15, V9) y los 4 tajos de
-- la cadena de golpes cuerpo a cuerpo ("Slash1"–"Slash4", Shared/MeleeChain) y la pose de guardia
-- ("Guard", Combat/Guard).
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
local Config = freshRequire(ReplicatedStorage.Shared.Config)
-- Se toma al cargar el módulo: build() corre en una copia que freshRequire ya ha sacado del árbol.
local MonkeyAnimationBuilder =
	freshRequire((script.Parent :: Instance):WaitForChild("MonkeyAnimationBuilder") :: ModuleScript)

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
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
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
	-- Elevación (grados) a la que apunta el arma con la pose puesta: la muñeca se gira lo que haga falta.
	-- Sin "aim", la muñeca no se toca (las armas que apuntan a la boca o al cielo a propósito).
	aim: number?,
	-- El golpe empieza en el "fxDelay" de Shared/Data/WeaponAnimations (marcador "Disparo").
}

-- Grados que sube la boca de un arma con "aim" al disparar.
local AIM_KICK = 6

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
	-- Rifle del Laboratorio: culata al hombro y cabeza ladeada para apuntar; al disparar, el hombro
	-- y la cabeza dan un respingo atrás.
	LabRifle = {
		pose = {
			Head = joint(-4),
			RightUpperArm = joint(-30, 10),
			RightLowerArm = joint(40),
			LeftUpperArm = joint(80, -38),
			LeftLowerArm = joint(28),
		},
		pulse = {
			UpperTorso = joint(-6),
			RightUpperArm = joint(-10),
			Head = joint(-3),
		},
		seconds = 0.9,
		raise = 0.08,
		pulseSeconds = 0.2,
		aim = 4,
	},
	-- Lanzarredes del Laboratorio: al costado, con una mano delante; al disparar, el torso se echa atrás.
	LabHarpoon = {
		pose = {
			RightUpperArm = joint(-60, 8),
			RightLowerArm = joint(50),
			LeftUpperArm = joint(70, -30),
			LeftLowerArm = joint(25),
		},
		pulse = {
			UpperTorso = joint(-10),
			RightUpperArm = joint(-20),
			LeftUpperArm = joint(-12, 12),
		},
		seconds = 0.6,
		raise = 0.08,
		pulseSeconds = 0.2,
		aim = 0,
	},
	-- Cañón de suero del Laboratorio: pesado, a la cadera; el cuerpo se echa atrás al disparar.
	LabCannon = {
		pose = {
			UpperTorso = joint(6, -10),
			RightUpperArm = joint(-60, 10),
			RightLowerArm = joint(40),
			LeftUpperArm = joint(58, -26),
			LeftLowerArm = joint(30),
		},
		pulse = {
			UpperTorso = joint(-16),
			RightUpperArm = joint(-28),
			LeftUpperArm = joint(-18),
		},
		seconds = 0.75,
		raise = 0.1,
		pulseSeconds = 0.26,
		aim = -3,
	},
}

-- Los tajos de la cadena de golpes (Fase 10, C4). No son ángulos de joint() sino specs como los de
-- PlayerAnimationBuilder (grados de CFrame.Angles en el espacio de la pieza de la que cuelga cada una;
-- ver ese archivo). Parten del reposo y vuelven a él: con el arma en la mano, al terminar sigue la
-- pose de empuñar de Roblox. WeaponController los estira a lo que dura cada paso, así que el golpe
-- (marcador "Golpe") va en Config.Chain.WindupFraction de su duración, igual que el daño en el
-- servidor; build() avisa si no. El arma va a lo largo de la palma: RightHand X− la lleva hacia
-- delante. Medido en Studio con el garrote de piedra (cabeza del arma: lado, delante, alto del suelo):
--   1. Vertical: de detrás de la cabeza (1,1; −4,7; 6,2) a delante del pecho (0,4; 5,5; 3,1) y abajo.
--   2. Barrido de derecha a izquierda: (5; −2; 4,4) → (1,2; 5; 2,7) → (−4,5; 1,4; 3,6).
--   3. Revés ascendente de izquierda a derecha: (−3,2; 2,7; 3,2) → (3,5; 4,1; 4,5) → (4,3; −0,7; 7).
--   4. Remate: con las dos manos de detrás de la cabeza al suelo, delante (4,6), en zancada (pies a
--      −0,13, como el Rompehuesos). Más largo, como su paso.
local function slamPose(t: number, marker: string?): { [string]: any }
	return {
		t = t,
		marcador = marker,
		LowerTorso = { -10, 0, 0, 0, -0.55, 0 },
		UpperTorso = { -30, 0, 0 },
		Head = { 20, 0, 0 },
		RightUpperArm = { 60, 0, -15 },
		RightLowerArm = { 5, 0, 0 },
		RightHand = { -40, 0, 0 },
		LeftUpperArm = { 60, 0, 25 },
		LeftLowerArm = { 10, 0, 0 },
		RightUpperLeg = { 65, 0, 0 },
		RightLowerLeg = { -75, 0, 0 },
		RightFoot = { 20, 0, 0 },
		LeftUpperLeg = { -10, 0, 0 },
		LeftLowerLeg = { -45, 0, 0 },
		LeftFoot = { 35, 0, 0 },
	}
end

local SLASHES: { [string]: any } = {
	Slash1 = {
		name = "Slash1",
		easing = "Cubic",
		direction = "Out",
		keyframes = {
			{ t = 0, reposo = true },
			{
				t = 0.15,
				direction = "In", -- acelera hacia el golpe
				UpperTorso = { 12, -20, 0 },
				Head = { -5, 15, 0 },
				RightUpperArm = { 170, 0, 15 },
				RightLowerArm = { 45, 0, 0 },
				RightHand = { -60, 0, 0 },
				LeftUpperArm = { 35, 0, -15 },
				LeftLowerArm = { 30, 0, 0 },
			},
			{
				t = 0.21,
				marcador = "Golpe",
				UpperTorso = { -15, 15, 0 },
				Head = { 8, -10, 0 },
				RightUpperArm = { 75, 0, 0 },
				RightLowerArm = { 5, 0, 0 },
				RightHand = { -60, 0, 0 },
				LeftUpperArm = { 10, 0, -25 },
				LeftLowerArm = { 20, 0, 0 },
			},
			{
				t = 0.32,
				UpperTorso = { -20, 20, 0 },
				Head = { 10, -12, 0 },
				RightUpperArm = { 35, 0, -10 },
				RightLowerArm = { 10, 0, 0 },
				RightHand = { -45, 0, 0 },
				LeftUpperArm = { 0, 0, -25 },
				LeftLowerArm = { 20, 0, 0 },
			},
			{ t = 0.6, reposo = true },
		},
	},
	Slash2 = {
		name = "Slash2",
		easing = "Cubic",
		direction = "Out",
		keyframes = {
			{ t = 0, reposo = true },
			{
				t = 0.15,
				direction = "In",
				LowerTorso = { 0, -20, 0 },
				UpperTorso = { 0, -50, 0 },
				Head = { 0, 45, 0 },
				RightUpperArm = { 45, 0, 35 },
				RightLowerArm = { 20, 0, 0 },
				RightHand = { -50, 0, 0 },
				LeftUpperArm = { 50, 0, -20 },
				LeftLowerArm = { 40, 0, 0 },
			},
			{
				t = 0.21,
				marcador = "Golpe",
				LowerTorso = { 0, 0, 0 },
				UpperTorso = { -5, 10, 0 },
				Head = { 0, -8, 0 },
				RightUpperArm = { 55, 0, 5 },
				RightLowerArm = { 5, 0, 0 },
				RightHand = { -55, 0, 0 },
				LeftUpperArm = { 25, 0, -30 },
				LeftLowerArm = { 20, 0, 0 },
			},
			{
				t = 0.32,
				LowerTorso = { 0, 20, 0 },
				UpperTorso = { -5, 50, 0 },
				Head = { 0, -45, 0 },
				RightUpperArm = { 50, 0, -30 },
				RightLowerArm = { 15, 0, 0 },
				RightHand = { -50, 0, 0 },
				LeftUpperArm = { 10, 0, -35 },
				LeftLowerArm = { 20, 0, 0 },
			},
			{ t = 0.6, reposo = true },
		},
	},
	Slash3 = {
		name = "Slash3",
		easing = "Cubic",
		direction = "Out",
		keyframes = {
			{ t = 0, reposo = true },
			{
				t = 0.15,
				direction = "In",
				LowerTorso = { 0, 20, 0 },
				UpperTorso = { -10, 50, 0 },
				Head = { 5, -45, 0 },
				RightUpperArm = { 10, 0, -30 },
				RightLowerArm = { 30, 0, 0 },
				RightHand = { -10, 0, 0 },
				LeftUpperArm = { 20, 0, -10 },
				LeftLowerArm = { 30, 0, 0 },
			},
			{
				t = 0.21,
				marcador = "Golpe",
				LowerTorso = { 0, 0, 0 },
				UpperTorso = { 0, -5, 0 },
				Head = { 0, 5, 0 },
				RightUpperArm = { 70, 0, 20 },
				RightLowerArm = { 5, 0, 0 },
				RightHand = { -55, 0, 0 },
				LeftUpperArm = { 30, 0, -35 },
				LeftLowerArm = { 20, 0, 0 },
			},
			{
				t = 0.32,
				LowerTorso = { 0, -15, 0 },
				UpperTorso = { 5, -30, 0 },
				Head = { -5, 25, 0 },
				RightUpperArm = { 90, 0, 30 },
				RightLowerArm = { 10, 0, 0 },
				RightHand = { -40, 0, 0 },
				LeftUpperArm = { 20, 0, -40 },
				LeftLowerArm = { 20, 0, 0 },
			},
			{ t = 0.6, reposo = true },
		},
	},
	Slash4 = {
		name = "Slash4",
		easing = "Cubic",
		direction = "Out",
		keyframes = {
			{ t = 0, reposo = true },
			{
				t = 0.24,
				direction = "In",
				UpperTorso = { 6, 0, 0 },
				Head = { -8, 0, 0 },
				RightUpperArm = { 165, 0, -10 },
				RightLowerArm = { 30, 0, 0 },
				RightHand = { -60, 0, 0 },
				LeftUpperArm = { 165, 0, 20 },
				LeftLowerArm = { 35, 0, 0 },
				RightUpperLeg = { 20, 0, 0 },
				RightLowerLeg = { -20, 0, 0 },
			},
			slamPose(0.315, "Golpe"),
			slamPose(0.5),
			{ t = 0.9, reposo = true },
		},
	},
}

-- La pose de guardia (Fase 10, C5; GuardController), en bucle y con el mismo formato que los tajos:
-- el antebrazo derecho alzado delante de la cara con el arma cruzada hacia la izquierda, el izquierdo
-- de través delante del pecho y el torso un poco encogido. Solo la parte de arriba: las piernas siguen
-- andando (en guardia se anda más despacio). Medido con el garrote de piedra (lado, delante, alto del
-- suelo): mano derecha (0,7; 1,1; 3,7), mano izquierda bajo el mango (−0,2; 1,4; 3,7) y cabeza del
-- arma a la izquierda y arriba (−2,3; 2,5; 4,7).
local GUARD_POSE: { [string]: any } = {
	UpperTorso = { 8, -12, 0 },
	Head = { -6, 10, 0 },
	RightUpperArm = { 60, 0, -40 },
	RightLowerArm = { 45, 0, 0 },
	RightHand = { -105, 45, 0 },
	LeftUpperArm = { 50, -20, 30 },
	LeftLowerArm = { 60, 0, 0 },
}

local GUARD: { [string]: any } = {
	name = "Guard",
	loop = true,
	priority = "Action3", -- por encima del brazo colgando (Hold) y de los tajos
	easing = "Cubic",
	direction = "Out",
	keyframes = {
		table.clone(GUARD_POSE),
		table.clone(GUARD_POSE),
	},
}
GUARD.keyframes[1].t = 0
GUARD.keyframes[2].t = 1

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
	local pose = table.clone(shot.pose)
	local pulse = table.clone(shot.pulse)
	if shot.aim then
		-- El arma sale a lo largo de la palma: apunta con la elevación de la suma de los ángulos del brazo (con la
		-- base de 90°) y del codo. La muñeca pone la diferencia hasta la elevación pedida.
		local upper = select(1, (pose.RightUpperArm or CFrame.new()):ToEulerAnglesYXZ())
		local lower = select(1, (pose.RightLowerArm or CFrame.new()):ToEulerAnglesYXZ())
		pose.RightHand = joint(shot.aim - (math.deg(upper) + 90 + math.deg(lower)))
		-- El golpe mueve el brazo: la muñeca lo compensa y sube la boca unos grados (el retroceso levanta el arma).
		local pulseUpper = select(1, (pulse.RightUpperArm or CFrame.new()):ToEulerAnglesYXZ())
		local pulseLower = select(1, (pulse.RightLowerArm or CFrame.new()):ToEulerAnglesYXZ())
		pulse.RightHand = joint(AIM_KICK - math.deg(pulseUpper) - math.deg(pulseLower))
		animated.RightHand = true
	end
	local posed: { [string]: CFrame } = {}
	local peak: { [string]: CFrame } = {}
	for part in animated do
		local base = BASE[part] or CFrame.new()
		local current = pose[part] or CFrame.new()
		posed[part] = current * base
		peak[part] = current * (pulse[part] or CFrame.new()) * base
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
	for name, spec in SLASHES do
		assert(WeaponAnimations[name], `[WeaponAnimationBuilder] Falta "{name}" en Data/WeaponAnimations`)
		local keyframes = spec.keyframes
		local length = keyframes[#keyframes].t
		for _, keyframe in keyframes do
			if keyframe.marcador and math.abs(keyframe.t / length - Config.Chain.WindupFraction) > 0.01 then
				warn(
					`[WeaponAnimationBuilder] El golpe de "{name}" va al {math.round(100 * keyframe.t / length)} % y el `
						.. `del servidor al {math.round(100 * Config.Chain.WindupFraction)} % (Config.Chain.WindupFraction)`
				)
			end
		end
		local sequence = MonkeyAnimationBuilder.sequence(spec, PARENT)
		sequence.Priority = Enum.AnimationPriority.Action2
		sequence.Parent = folder
	end
	assert(WeaponAnimations.Guard, `[WeaponAnimationBuilder] Falta "Guard" en Data/WeaponAnimations`)
	MonkeyAnimationBuilder.sequence(GUARD, PARENT).Parent = folder
	folder.Parent = ReplicatedStorage
	print(
		"[WeaponAnimationBuilder] Listo: ReplicatedStorage.WeaponAnimations (Hold, Stone, Arrow, Spell, Dart, "
			.. "LabRifle, LabHarpoon, LabCannon, Slash1–Slash4, Guard).\n"
			.. "  Pruébalas con Play (en Studio se usan mientras su id esté vacío).\n"
			.. "  Para publicarlas: clic derecho en cada una > Save to Roblox, y pega cada id en\n"
			.. "  src/shared/Data/WeaponAnimations.luau (con el mismo dueño que el juego)."
	)
end

return WeaponAnimationBuilder
