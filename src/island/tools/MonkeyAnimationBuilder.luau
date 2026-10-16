--!strict
-- Generador de las animaciones de los monos y los jefes (las que reproduce Monkeys/MonkeyAnimator).
-- Se ejecuta en Studio, en modo edición (sin pulsar Play), desde la barra de comandos:
--
--   require(game.ServerStorage.Tools.MonkeyAnimationBuilder).build()                 -- todas
--   require(game.ServerStorage.Tools.MonkeyAnimationBuilder).build("MonosPequenos")  -- un lote
--
-- Cada módulo de MonkeyAnimationSpecs es un lote ("MonosPequenos", "MonosMedianosYGrandes",
-- "GorilaDeCeniza") con sus animaciones escritas como tablas (el formato "spec" de la skill
-- animaciones-roblox, ver abajo). build() crea (o sustituye) una KeyframeSequence por spec en
-- ServerStorage.RBX_ANIMSAVES.<lote>, donde también las encuentra el Animation Editor. Para el juego:
-- clic derecho en cada una > "Save to Roblox" (con el mismo dueño que el juego) y pegar el id en
-- Shared/Data/MonkeyAnimations, en el hueco que lleva su nombre.
--
-- Para retocar una animación, cambia su spec aquí, vuelve a ejecutar build() y publícala de nuevo
-- (sale otro id). Formato de un spec:
--   { name = "Titi_Run", loop = true, priority = "Movement", easing = "Cubic", direction = "InOut",
--     keyframes = { { t = 0, ["Right Arm"] = { 50, 0, 0 }, Torso = { 8, 0, 0 } }, … } }
-- Cada pose es { x, y, z } en grados (CFrame.Angles, en el espacio de la pieza de la que cuelga).
-- "reposo = true" pone a 0 las piezas animadas que el fotograma no nombra; sin él, la pieza que no
-- aparece no tiene pose ahí y se interpola. "marcador" añade un KeyframeMarker. "easing" y
-- "direction" en un fotograma rigen el tramo que sale de él (por defecto, los del spec).
-- Solo rotaciones: las piezas de los monos se escalan por tamaño y un desplazamiento en studs no.

local ServerStorage = game:GetService("ServerStorage")

-- Se toma al cargar el módulo: build() corre en una copia que freshRequire ya ha sacado del árbol.
local SPECS_FOLDER = (script.Parent :: Instance):WaitForChild("MonkeyAnimationSpecs")

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

export type Spec = {
	name: string,
	loop: boolean?,
	priority: string?,
	easing: string?,
	direction: string?,
	keyframes: { { [string]: any } },
}

-- De qué pieza cuelga cada una en el rig de MonkeyModels (igual en todas las especies).
local PARENT: { [string]: string } = {
	Torso = "HumanoidRootPart",
	Head = "Torso",
	["Right Arm"] = "Torso",
	["Left Arm"] = "Torso",
	["Right Leg"] = "Torso",
	["Left Leg"] = "Torso",
	Tail = "Torso",
}

local RESERVED: { [string]: boolean } = { t = true, reposo = true, marcador = true, easing = true, direction = true }

local MonkeyAnimationBuilder = {}

-- Piezas que anima un spec (las que aparecen en algún fotograma).
local function animatedParts(spec: Spec): { string }
	local seen: { [string]: boolean } = {}
	local list: { string } = {}
	for _, frame in spec.keyframes do
		for key, value in frame do
			if not RESERVED[key] and type(value) == "table" and not seen[key] then
				assert(PARENT[key], `[MonkeyAnimationBuilder] {spec.name}: "{key}" no es una pieza del rig`)
				seen[key] = true
				table.insert(list, key)
			end
		end
	end
	table.sort(list)
	return list
end

-- Convierte un spec en KeyframeSequence. Las poses que solo dan la jerarquía (la raíz, el torso sin
-- animar) llevan peso 0: no tocan esa articulación (así las piernas siguen andando bajo un Attack).
function MonkeyAnimationBuilder.sequence(spec: Spec): KeyframeSequence
	local parts = animatedParts(spec)
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = spec.name
	sequence.Loop = spec.loop == true
	sequence.Priority = (Enum.AnimationPriority :: any)[spec.priority or "Action"]
	for _, frame in spec.keyframes do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = frame.t
		local poses: { [string]: Pose } = {}
		local function poseOf(name: string): Pose
			local existing = poses[name]
			if existing then
				return existing
			end
			local pose = Instance.new("Pose")
			pose.Name = name
			pose.Weight = 0
			poses[name] = pose
			local parentName = PARENT[name]
			if parentName then
				poseOf(parentName):AddSubPose(pose)
			else
				keyframe:AddPose(pose)
			end
			return pose
		end
		for _, name in parts do
			local value = frame[name]
			if value == nil and not frame.reposo then
				continue
			end
			local pose = poseOf(name)
			pose.Weight = 1
			if value then
				pose.CFrame = CFrame.Angles(math.rad(value[1] or 0), math.rad(value[2] or 0), math.rad(value[3] or 0))
			end
			pose.EasingStyle = (Enum.PoseEasingStyle :: any)[frame.easing or spec.easing or "Linear"]
			pose.EasingDirection = (Enum.PoseEasingDirection :: any)[frame.direction or spec.direction or "In"]
		end
		if frame.marcador then
			local marker = Instance.new("KeyframeMarker")
			marker.Name = frame.marcador
			keyframe:AddMarker(marker)
		end
		sequence:AddKeyframe(keyframe)
	end
	return sequence
end

function MonkeyAnimationBuilder.build(only: string?, options: { fresh: boolean? }?)
	-- Genera siempre con el código actual (ver freshRequire).
	if not (options and options.fresh) then
		freshRequire(script :: ModuleScript).build(only, { fresh = true })
		return
	end
	local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
	if not saves then
		saves = Instance.new("Model")
		saves.Name = "RBX_ANIMSAVES"
		saves.Parent = ServerStorage
	end
	local built = {}
	for _, module in SPECS_FOLDER:GetChildren() do
		if not module:IsA("ModuleScript") or (only and module.Name ~= only) then
			continue
		end
		local specs: { [string]: Spec } = freshRequire(module)
		-- Mismo contenedor que usa el Animation Editor (un ObjectValue por rig).
		local folder = (saves :: Instance):FindFirstChild(module.Name)
		if not folder then
			folder = Instance.new("ObjectValue")
			folder.Name = module.Name
			folder.Parent = saves
		end
		local count = 0
		for name, spec in specs do
			assert(
				spec.name == name,
				`[MonkeyAnimationBuilder] {module.Name}: la clave {name} y el nombre {spec.name} no coinciden`
			)
			local old = (folder :: Instance):FindFirstChild(name)
			if old then
				old:Destroy()
			end
			MonkeyAnimationBuilder.sequence(spec).Parent = folder
			count += 1
		end
		table.insert(built, `{module.Name} ({count})`)
	end
	assert(#built > 0, `[MonkeyAnimationBuilder] No hay ningún lote llamado {only}`)
	print(
		`[MonkeyAnimationBuilder] Listo: ServerStorage.RBX_ANIMSAVES > {table.concat(built, ", ")}.\n`
			.. "  Para publicarlas: clic derecho en cada una > Save to Roblox (mismo dueño que el juego),\n"
			.. "  y pega cada id en src/shared/Data/MonkeyAnimations.luau, en el hueco con su nombre."
	)
end

return MonkeyAnimationBuilder
