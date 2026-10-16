--!strict
-- Generador de las animaciones del cuerpo del jugador (R15) que no son de armas (Shared/Data/
-- PlayerAnimations). Se ejecuta en Studio, en modo edición (sin pulsar Play), desde la barra de
-- comandos:
--
--   require(game.ServerStorage.Tools.PlayerAnimationBuilder).build()
--
-- Crea (o sustituye) ReplicatedStorage.PlayerAnimations con una KeyframeSequence por animación.
-- Para probarlas basta con pulsar Play: en Studio, Client/BodyAnimations usa estas secuencias
-- mientras su id esté vacío. Para el juego publicado: clic derecho en cada una > "Save to Roblox"
-- (con el mismo dueño que el juego) y pegar el id en Shared/Data/PlayerAnimations.
--
-- Mismo formato que MonkeyAnimationBuilder: poses { x, y, z } en grados en el espacio de la pieza
-- de la que cuelga cada una, y { x, y, z, px, py, pz } con un desplazamiento en studs (el jugador
-- mide siempre lo mismo). En el R15: X positivo lleva un brazo o un muslo hacia delante y arriba;
-- el codo (LowerArm) se dobla con X+ y la rodilla (LowerLeg) con X−; el torso (LowerTorso,
-- UpperTorso) se inclina hacia delante con X−. El suelo queda 3,19 studs bajo la raíz.
-- Un fotograma solo mantiene una pose si la repite: uno vacío deja interpolar entre sus vecinos.
-- Medidas en Studio (skill animaciones-roblox): pies a menos de 0,15 del suelo, mano a la boca al
-- comer, palma apoyada al arrastrarse (0,26 bajo el suelo).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Ver MonkeyAnimationBuilder: copia recién clonada para no usar código viejo de la caché de Studio.
local function freshRequire(module: ModuleScript): any
	local copy = module:Clone()
	copy.Parent = module.Parent
	local result = require(copy) :: any
	copy:Destroy()
	return result
end

-- Se toma al cargar el módulo: build() corre en una copia que freshRequire ya ha sacado del árbol.
local MonkeyAnimationBuilder =
	freshRequire((script.Parent :: Instance):WaitForChild("MonkeyAnimationBuilder") :: ModuleScript)
local PlayerAnimations = freshRequire(ReplicatedStorage.Shared.Data.PlayerAnimations)

local FOLDER_NAME = "PlayerAnimations"

-- De qué pieza cuelga cada una en el rig R15.
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

-- Pose de las dos piernas a la vez (agachado o en cuclillas).
local function legs(frame: { [string]: any }, thigh: number, knee: number, foot: number)
	for _, side in { "Right", "Left" } do
		frame[`{side}UpperLeg`] = { thigh, 0, 0 }
		frame[`{side}LowerLeg`] = { knee, 0, 0 }
		frame[`{side}Foot`] = { foot, 0, 0 }
	end
	return frame
end

-- Arrastrarse caído: tumbado boca abajo (la cadera baja 1,55), estira un brazo y tira con el otro,
-- y patalea con la pierna contraria. "side" 1 o -1 elige qué brazo estira.
local function crawlPose(t: number, side: number): { [string]: any }
	local reach, pull = { 158, 10 }, { 128, 30 }
	local right = if side == 1 then reach else pull
	local left = if side == 1 then pull else reach
	return {
		t = t,
		LowerTorso = { -80, 0, 0, 0, -1.55, 0 },
		UpperTorso = { 0, 0, 0 },
		Head = { 60, 0, 0 }, -- con el cuerpo tumbado, mira hacia delante
		RightUpperArm = { right[1], 0, 10 },
		RightLowerArm = { right[2], 0, 0 },
		LeftUpperArm = { left[1], 0, -10 },
		LeftLowerArm = { left[2], 0, 0 },
		RightUpperLeg = { if side == 1 then 12 else -5, 0, 0 },
		RightLowerLeg = { if side == 1 then -40 else -5, 0, 0 },
		LeftUpperLeg = { if side == 1 then -5 else 12, 0, 0 },
		LeftLowerLeg = { if side == 1 then -5 else -40, 0, 0 },
	}
end

-- Reanimar: de rodillas (la izquierda en el suelo) empujando con las dos manos sobre el aliado.
local function revivePose(t: number, push: boolean): { [string]: any }
	return {
		t = t,
		LowerTorso = { 0, 0, 0, 0, -0.85, 0 },
		RightUpperLeg = { 90, 0, 0 },
		RightLowerLeg = { -90, 0, 0 },
		LeftUpperLeg = { 0, 0, 0 },
		LeftLowerLeg = { -90, 0, 0 },
		LeftFoot = { 0, 0, 0 },
		UpperTorso = { if push then -38 else -25, 0, 0 },
		Head = { if push then 15 else 8, 0, 0 },
		RightUpperArm = { if push then 45 else 60, 0, 5 },
		LeftUpperArm = { if push then 45 else 60, 0, -5 },
		RightLowerArm = { if push then 5 else 25, 0, 0 },
		LeftLowerArm = { if push then 5 else 25, 0, 0 },
	}
end

-- Vendarse: el antebrazo izquierdo cruzado delante y la mano derecha dando vueltas alrededor.
local function bandagePose(t: number, around: boolean): { [string]: any }
	return {
		t = t,
		LeftUpperArm = { 55, 0, 30 },
		LeftLowerArm = { 45, 0, 0 },
		RightUpperArm = if around then { 60, 0, -38 } else { 45, 0, -30 },
		RightLowerArm = { if around then 45 else 70, 0, 0 },
		Head = { -15, 0, 0 },
	}
end

-- Comer o beber: mano a la boca (el giro en Y lleva el antebrazo al centro de la cara).
local function mouthPose(t: number, near: boolean, head: number, marker: string?): { [string]: any }
	return {
		t = t,
		marcador = marker,
		RightUpperArm = if near then { 30, 65, -20 } else { 28, 60, -18 },
		RightLowerArm = { if near then 125 else 105, 0, 0 },
		Head = { head, 0, 0 },
	}
end

local SPECS: { [string]: any } = {
	-- Pisotón del guerrero. AbilityService hace el daño al recibir la petición: el pie cae a 0,2 s.
	Quake = {
		name = "Quake",
		easing = "Cubic",
		direction = "Out",
		keyframes = {
			{ t = 0, reposo = true },
			{
				t = 0.1,
				direction = "In",
				LowerTorso = { 8, 0, 0 },
				RightUpperLeg = { 85, 0, 0 },
				RightLowerLeg = { -80, 0, 0 },
				LeftUpperLeg = { -8, 0, 0 },
				RightUpperArm = { 150, 0, 15 },
				LeftUpperArm = { 150, 0, -15 },
				RightLowerArm = { 20, 0, 0 },
				LeftLowerArm = { 20, 0, 0 },
				Head = { -8, 0, 0 },
			},
			legs({
				t = 0.2,
				marcador = "Impacto",
				LowerTorso = { -15, 0, 0, 0, -0.5, 0 },
				RightUpperArm = { 30, 0, 25 },
				LeftUpperArm = { 30, 0, -25 },
				RightLowerArm = { 10, 0, 0 },
				LeftLowerArm = { 10, 0, 0 },
				Head = { -10, 0, 0 },
			}, 60, -93, 33),
			legs({
				t = 0.45,
				LowerTorso = { -8, 0, 0, 0, -0.25, 0 },
				RightUpperArm = { 20, 0, 15 },
				LeftUpperArm = { 20, 0, -15 },
				RightLowerArm = { 10, 0, 0 },
				LeftLowerArm = { 10, 0, 0 },
				Head = { -5, 0, 0 },
			}, 40, -62, 30),
			{ t = 0.75, reposo = true },
		},
	},
	-- Lanza con la mano derecha al frente (bola de fuego, rayo, dardo, marcar presa). Solo el tronco
	-- y los brazos: si anda, las piernas siguen andando.
	CastForward = {
		name = "CastForward",
		easing = "Cubic",
		direction = "Out",
		keyframes = {
			{ t = 0, reposo = true },
			{
				t = 0.08,
				UpperTorso = { 0, -15, 0 },
				RightUpperArm = { 40, 0, 10 },
				RightLowerArm = { 80, 0, 0 },
				LeftUpperArm = { 20, 0, 0 },
				Head = { 0, 12, 0 },
			},
			{
				t = 0.16,
				marcador = "Lanzar",
				UpperTorso = { 0, 18, 0 },
				RightUpperArm = { 90, 18, 0 },
				RightLowerArm = { 5, 0, 0 },
				RightHand = { -30, 0, 0 },
				LeftUpperArm = { -15, 0, 0 },
				Head = { 0, -15, 0 },
			},
			{
				t = 0.35,
				UpperTorso = { 0, 14, 0 },
				RightUpperArm = { 85, 18, 0 },
				RightLowerArm = { 10, 0, 0 },
				RightHand = { -25, 0, 0 },
				LeftUpperArm = { -10, 0, 0 },
				Head = { 0, -12, 0 },
			},
			{ t = 0.55, reposo = true },
		},
	},
	-- Hechizo de área: los dos brazos arriba y luego abiertos hacia abajo (nova de hielo, curación
	-- en área, escudo de hojas, lluvia de flechas). Solo el tronco y los brazos.
	CastArea = {
		name = "CastArea",
		easing = "Cubic",
		direction = "Out",
		keyframes = {
			{ t = 0, reposo = true },
			{
				t = 0.14,
				UpperTorso = { 8, 0, 0 },
				RightUpperArm = { 165, 0, 15 },
				LeftUpperArm = { 165, 0, -15 },
				RightLowerArm = { 10, 0, 0 },
				LeftLowerArm = { 10, 0, 0 },
				Head = { 15, 0, 0 },
			},
			{
				t = 0.26,
				marcador = "Lanzar",
				UpperTorso = { -10, 0, 0 },
				RightUpperArm = { 60, 0, 55 },
				LeftUpperArm = { 60, 0, -55 },
				RightLowerArm = { 5, 0, 0 },
				LeftLowerArm = { 5, 0, 0 },
				RightHand = { -20, 0, 0 },
				LeftHand = { -20, 0, 0 },
				Head = { -8, 0, 0 },
			},
			{
				t = 0.45,
				UpperTorso = { -6, 0, 0 },
				RightUpperArm = { 50, 0, 50 },
				LeftUpperArm = { 50, 0, -50 },
				RightLowerArm = { 5, 0, 0 },
				LeftLowerArm = { 5, 0, 0 },
				Head = { -4, 0, 0 },
			},
			{ t = 0.65, reposo = true },
		},
	},
	-- Se agacha a dejar algo en el suelo (trampa, tótem) y se levanta.
	Place = {
		name = "Place",
		easing = "Cubic",
		direction = "Out",
		keyframes = {
			{ t = 0, reposo = true },
			{
				t = 0.2,
				marcador = "Dejar",
				LowerTorso = { -20, 0, 0, 0, -0.85, 0 },
				UpperTorso = { -32, 0, 0 },
				RightUpperLeg = { 95, 0, 0 },
				RightLowerLeg = { -110, 0, 0 },
				RightFoot = { 35, 0, 0 },
				LeftUpperLeg = { 70, 0, 0 },
				LeftLowerLeg = { -120, 0, 0 },
				LeftFoot = { 70, 0, 0 },
				RightUpperArm = { 70, 0, 5 },
				LeftUpperArm = { 70, 0, -5 },
				RightLowerArm = { 20, 0, 0 },
				LeftLowerArm = { 20, 0, 0 },
				Head = { 30, 0, 0 },
			},
			{
				t = 0.45,
				LowerTorso = { -20, 0, 0, 0, -0.85, 0 },
				UpperTorso = { -32, 0, 0 },
				RightUpperLeg = { 95, 0, 0 },
				RightLowerLeg = { -110, 0, 0 },
				RightFoot = { 35, 0, 0 },
				LeftUpperLeg = { 70, 0, 0 },
				LeftLowerLeg = { -120, 0, 0 },
				LeftFoot = { 70, 0, 0 },
				RightUpperArm = { 70, 0, 5 },
				LeftUpperArm = { 70, 0, -5 },
				RightLowerArm = { 20, 0, 0 },
				LeftLowerArm = { 20, 0, 0 },
				Head = { 30, 0, 0 },
			},
			{ t = 0.7, reposo = true },
		},
	},
	-- Comer o beber: dos veces la mano a la boca.
	Consume = {
		name = "Consume",
		easing = "Cubic",
		direction = "InOut",
		keyframes = {
			{ t = 0, reposo = true },
			mouthPose(0.15, true, 8, "Boca"),
			mouthPose(0.3, false, 3),
			mouthPose(0.45, true, 10),
			mouthPose(0.6, true, 10),
			{ t = 0.85, reposo = true },
		},
	},
	-- Curarse con vendas o ungüentos.
	Bandage = {
		name = "Bandage",
		easing = "Cubic",
		direction = "InOut",
		keyframes = {
			{ t = 0, reposo = true },
			bandagePose(0.12, false),
			bandagePose(0.3, true),
			bandagePose(0.48, false),
			bandagePose(0.66, true),
			{ t = 0.9, reposo = true },
		},
	},
	-- Caído: en bucle mientras dura; BodyAnimations ajusta su velocidad a lo que se mueve.
	Crawl = {
		name = "Crawl",
		loop = true,
		easing = "Cubic",
		direction = "InOut",
		keyframes = { crawlPose(0, 1), crawlPose(0.5, -1), crawlPose(1, 1) },
	},
	-- Reanimar: en bucle mientras se mantiene pulsado el aviso "Reanimar".
	Revive = {
		name = "Revive",
		loop = true,
		easing = "Cubic",
		direction = "InOut",
		keyframes = { revivePose(0, false), revivePose(0.3, true), revivePose(0.6, false) },
	},
}

local PlayerAnimationBuilder = {}

PlayerAnimationBuilder.SPECS = SPECS

function PlayerAnimationBuilder.build(options: { fresh: boolean? }?)
	-- Genera siempre con el código actual (ver freshRequire).
	if not (options and options.fresh) then
		freshRequire(script :: ModuleScript).build({ fresh = true })
		return
	end
	local old = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	local names = {}
	for key, data in PlayerAnimations.Animations do
		local spec = SPECS[key]
		assert(spec, `[PlayerAnimationBuilder] Falta el spec de "{key}" (Data/PlayerAnimations)`)
		local sequence = MonkeyAnimationBuilder.sequence(spec, PARENT)
		sequence.Priority = data.priority
		sequence.Loop = data.looped == true
		sequence.Parent = folder
		table.insert(names, key)
	end
	table.sort(names)
	folder.Parent = ReplicatedStorage
	print(
		`[PlayerAnimationBuilder] Listo: ReplicatedStorage.PlayerAnimations ({table.concat(names, ", ")}).\n`
			.. "  Pruébalas con Play (en Studio se usan mientras su id esté vacío).\n"
			.. "  Para publicarlas: clic derecho en cada una > Save to Roblox (mismo dueño que el juego),\n"
			.. "  y pega cada id en src/shared/Data/PlayerAnimations.luau."
	)
end

return PlayerAnimationBuilder
