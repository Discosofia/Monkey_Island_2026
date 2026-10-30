--!strict
-- Generador de las animaciones de los brazos en primera persona del Laboratorio (Fase 19, W10). Se ejecuta en
-- Studio, en modo edición, desde la barra de comandos:
--
--   require(game.ServerStorage.Tools.ViewModelAnimationBuilder).build()
--
-- Crea (o sustituye) ReplicatedStorage.ViewModelAnimations con una KeyframeSequence por arma y clave
-- ("<arma>_<clave>": LabDartGun_Aim, LabDartGun_Fire… 4 armas × 5 pistas = 20). Las poses siguen la jerarquía de
-- Shared/LabViewModelRig (el nombre de la pose es el de la pieza: RightUpperArm, RightLowerArm, RightHand y las
-- de la izquierda; la raíz es "Root"). En Studio, CombatClient/ViewModelAnimationIds las usa mientras el id de
-- Shared/Data/ViewModelAnimations esté vacío. Para el juego publicado: clic derecho en cada una > Save to Roblox
-- y pegar el id allí.
--
-- Los ángulos son en grados sobre el reposo «de cadera» del rig, alrededor de los ejes de la cámara: X positivo
-- sube la boca (lo que va hacia delante), Y positivo lleva el brazo a la izquierda, Z inclina de costado. Los tres
-- últimos números de una pose son un desplazamiento en studs (derecha, arriba, atrás). Las tablas de abajo se
-- retocan a mano; vuelve a ejecutar build() y publica de nuevo (y cambia el id).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- En Studio, require guarda el resultado de cada módulo durante toda la sesión: una copia recién clonada se
-- carga siempre desde cero (como WeaponAnimationBuilder).
local function freshRequire(module: ModuleScript): any
	local copy = module:Clone()
	copy.Parent = module.Parent
	local result = require(copy) :: any
	copy:Destroy()
	return result
end

local ViewModelAnimations = freshRequire(ReplicatedStorage.Shared.Data.ViewModelAnimations)
local LabWeapons = freshRequire(ReplicatedStorage.Shared.Data.LabWeapons)
-- Se toma al cargar el módulo: build() corre en una copia que freshRequire ya ha sacado del árbol.
local MonkeyAnimationBuilder =
	freshRequire((script.Parent :: Instance):WaitForChild("MonkeyAnimationBuilder") :: ModuleScript)

local FOLDER_NAME = "ViewModelAnimations"

-- De qué pieza cuelga cada una en el rig (Shared/LabViewModelRig).
local PARENT: { [string]: string } = {
	RightUpperArm = "Root",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperArm = "Root",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
}

type Pose = { number }
type Frame = { [string]: any }

-- Aim (bucle de 1 s): sobre la cadera, los codos hacia dentro (el hombro gira y el codo lo compensa, así las
-- manos no se mueven) y una respiración ligera. El arma sube al centro por código (desplazamiento de la cámara).
local AIM_SECONDS = 1
local function aimFrame(t: number, breath: number): Frame
	return {
		t = t,
		RightUpperArm = { breath, 4, 0 },
		RightLowerArm = { 0, -4, 0 },
		LeftUpperArm = { breath, -4, 0 },
		LeftLowerArm = { 0, 4, 0 },
	}
end

-- Fire: por arma, lo que dura (s; en el lanzadardos, menos que su cadencia de 0,15 s) y cuánto recorrido tiene
-- el retroceso (1 = el del rifle).
local FIRE: { [string]: { seconds: number, scale: number } } = {
	LabDartGun = { seconds = 0.12, scale = 0.4 },
	LabBananaRifle = { seconds = 0.2, scale = 1 },
	LabNetHarpoon = { seconds = 0.2, scale = 0.9 },
	LabAcidCannon = { seconds = 0.2, scale = 1.2 },
}
-- Lo más fuerte del retroceso con scale = 1: grados de los hombros, grados de la muñeca derecha (levanta la
-- boca) y studs hacia atrás.
local FIRE_SHOULDER = 3
local FIRE_WRIST = 9
local FIRE_BACK = 0.35

-- Reload (1 s; el controlador la estira a la recarga real): el arma baja y se inclina, la mano izquierda va al
-- cargador, golpe del cargador (0,55) y vuelve a subir.
local RELOAD_LOW = { -6, 0, 0, 0, -0.7, 0.1 } -- hombro derecho con el arma abajo
local RELOAD_FRAMES: { Frame } = {
	{ t = 0, reposo = true },
	{
		t = 0.15,
		RightUpperArm = RELOAD_LOW,
		RightHand = { 32, 0, 0 },
		LeftUpperArm = { -10, -8, 0, 0, -0.7, 0.1 },
	},
	{
		t = 0.35,
		RightUpperArm = RELOAD_LOW,
		RightHand = { 34, 6, 0 },
		LeftUpperArm = { -28, 12, 0, 0, -0.7, 0.1 },
		LeftLowerArm = { 18, 0, 0 },
	},
	{
		t = 0.55,
		RightUpperArm = { -6, 0, 0, 0, -0.7, -0.1 },
		RightHand = { 30, 0, 0 },
		LeftUpperArm = { -20, 10, 0, 0, -0.7, -0.05 },
		LeftLowerArm = { 10, 0, 0 },
	},
	{
		t = 0.65,
		RightUpperArm = RELOAD_LOW,
		RightHand = { 32, 0, 0 },
		LeftUpperArm = { -10, -8, 0, 0, -0.7, 0.1 },
	},
	{
		t = 0.85,
		RightUpperArm = RELOAD_LOW,
		RightHand = { 32, 0, 0 },
		LeftUpperArm = { -10, -8, 0, 0, -0.7, 0.1 },
	},
	{ t = 1, reposo = true },
}

-- Sprint (bucle de 0,5 s): el arma baja y de lado (hacia la derecha) con un balanceo de paso.
local SPRINT_SECONDS = 0.5
local function sprintFrame(t: number, swing: number): Frame
	return {
		t = t,
		RightUpperArm = { -14 - swing, -12 - swing, 0, 0, -0.6 - swing * 0.02, 0.15 },
		RightHand = { 10, 0, 18 },
		LeftUpperArm = { -12 - swing, -26 - swing, 0, 0, -0.6 - swing * 0.02, 0.15 },
		LeftLowerArm = { 8, 0, 0 },
	}
end

-- Equip (0,35 s): sube desde abajo hasta el reposo (empieza abajo, no en reposo).
local EQUIP_SECONDS = 0.35
local EQUIP_FRAMES: { Frame } = {
	{
		t = 0,
		RightUpperArm = { -8, 0, 0, 0, -1.3, 0.2 },
		RightHand = { 36, 0, 0 },
		LeftUpperArm = { -8, 0, 0, 0, -1.3, 0.2 },
	},
	{ t = EQUIP_SECONDS, reposo = true },
}

-- Multiplica por "s" los giros de una pose (los desplazamientos también).
local function scaled(pose: Pose, s: number): Pose
	local result = {}
	for i, value in pose do
		result[i] = value * s
	end
	return result
end

local function fireFrames(scale: number, seconds: number): { Frame }
	local shoulder = { FIRE_SHOULDER, 0, 0, 0, 0, FIRE_BACK }
	return {
		{ t = 0, reposo = true, direction = "Out" },
		{
			t = seconds * 0.25,
			direction = "InOut",
			RightUpperArm = scaled(shoulder, scale),
			RightHand = scaled({ FIRE_WRIST, 0, 0 }, scale),
			LeftUpperArm = scaled(shoulder, scale),
		},
		{ t = seconds, reposo = true },
	}
end

-- Una secuencia desde un spec; "priority" la pone por encima de lo que suena debajo.
local function sequence(name: string, loop: boolean, priority: string, frames: { Frame }): KeyframeSequence
	return MonkeyAnimationBuilder.sequence({
		name = name,
		loop = loop,
		priority = priority,
		easing = "Cubic",
		direction = "InOut",
		keyframes = frames,
	}, PARENT)
end

-- Las cinco pistas de un arma, por clave de Data/ViewModelAnimations.KEYS.
local function tracksOf(weaponId: string): { [string]: KeyframeSequence }
	local fire = FIRE[weaponId]
	assert(fire, `[ViewModelAnimationBuilder] Falta "{weaponId}" en FIRE`)
	local weapon = LabWeapons.weapons[weaponId]
	assert(
		weapon and fire.seconds <= weapon.cooldownSeconds,
		`[ViewModelAnimationBuilder] Fire de "{weaponId}" dura más que su cadencia`
	)
	return {
		Aim = sequence(
			`{weaponId}_Aim`,
			true,
			"Action",
			{ aimFrame(0, 0), aimFrame(AIM_SECONDS / 2, 1.2), aimFrame(AIM_SECONDS, 0) }
		),
		Fire = sequence(`{weaponId}_Fire`, false, "Action3", fireFrames(fire.scale, fire.seconds)),
		Reload = sequence(`{weaponId}_Reload`, false, "Action3", RELOAD_FRAMES),
		Sprint = sequence(
			`{weaponId}_Sprint`,
			true,
			"Action2",
			{ sprintFrame(0, 0), sprintFrame(SPRINT_SECONDS / 2, 4), sprintFrame(SPRINT_SECONDS, 0) }
		),
		Equip = sequence(`{weaponId}_Equip`, false, "Action4", EQUIP_FRAMES),
	}
end

local ViewModelAnimationBuilder = {}

function ViewModelAnimationBuilder.build(options: { fresh: boolean? }?)
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
	local count = 0
	for _, weaponId in LabWeapons.ORDER do
		local tracks = tracksOf(weaponId)
		for _, key in ViewModelAnimations.KEYS do
			local track = tracks[key]
			assert(track, `[ViewModelAnimationBuilder] Falta la pista "{key}" de "{weaponId}"`)
			track.Parent = folder
			count += 1
		end
	end
	folder.Parent = ReplicatedStorage
	print(
		`[ViewModelAnimationBuilder] Listo: ReplicatedStorage.ViewModelAnimations ({count} secuencias "<arma>_<clave>").\n`
			.. "  Pruébalas con Play (en Studio se usan mientras su id esté vacío).\n"
			.. "  Para publicarlas: clic derecho en cada una > Save to Roblox, y pega cada id en\n"
			.. "  src/shared/Data/ViewModelAnimations.luau (con el mismo dueño que el juego)."
	)
end

return ViewModelAnimationBuilder
