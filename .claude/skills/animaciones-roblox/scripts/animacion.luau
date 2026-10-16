-- Biblioteca para crear, revisar y retocar animaciones (KeyframeSequence) en Roblox Studio desde
-- la herramienta execute_luau del MCP (datamodel_type = "Edit"). No es un ModuleScript del juego: se
-- pega entera, se guarda en _G.Anim y al final se añade el código del encargo, por ejemplo:
--
--   _G.Anim = Anim
--   local rig = Anim.monkeyRig("Gorila")
--   local ks = Anim.build(SPEC, rig)
--   return Anim.show(rig, ks)
--
-- En las llamadas siguientes basta con `local Anim = _G.Anim` (dura hasta que se cierra Studio).
--
-- Las animaciones se describen con una tabla "spec" (ver SKILL.md, "Formato spec"):
--
--   {
--   	name = "Attack", loop = false, priority = "Action", easing = "Cubic", direction = "Out",
--   	keyframes = {
--   		{ t = 0, reposo = true },
--   		{ t = 0.12, ["Right Arm"] = { -40, 0, 0 }, Head = { 10, 0, 0 } },
--   		{ t = 0.22, ["Right Arm"] = { 80, 0, 0 }, Head = { -10, 0, 0 }, marcador = "Golpe" },
--   		{ t = 0.4, reposo = true },
--   	},
--   }
--
-- Cada pose es { x, y, z } en grados (los de CFrame.Angles, en el espacio de la pieza de la que
-- cuelga) y opcionalmente { x, y, z, px, py, pz } con un desplazamiento en studs. "reposo = true"
-- pone a 0 todas las piezas animadas que ese fotograma no nombre. Sin "reposo", la pieza que no se
-- nombra no tiene pose en ese fotograma y Roblox la interpola entre los de alrededor.
--
-- show() pone en Workspace._VistaAnimacion (lejos del mapa) una tira de copias del rig, cada una
-- congelada en un instante de la animación, con su tiempo encima, y devuelve un JSON con las cámaras
-- para screen_capture y los avisos (pies que se hunden o flotan, bucles que no cierran…).

local HttpService = game:GetService("HttpService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local FOLDER = "_VistaAnimacion"
-- Lejos de la isla (radio 950), del Lobby y de la vista previa de modelos (0, 300, 4000).
local ORIGIN = Vector3.new(0, 300, 4400)
local LOAD_TIMEOUT = 8

local Anim = {}

-- ===== Utilidades =====

local function round(value: number, decimals: number?): number
	local factor = 10 ^ (decimals or 2)
	return math.floor(value * factor + 0.5) / factor
end

local function vector(value: Vector3): { number }
	return { round(value.X), round(value.Y), round(value.Z) }
end

-- Instancia a partir de una ruta con puntos ("ReplicatedStorage.Shared.Data.MonkeyAnimations").
function Anim.find(path: string): Instance
	local current: Instance = game
	for name in string.gmatch(path, "[^%.]+") do
		local child = if current == game then game:GetService(name) else current:FindFirstChild(name)
		assert(child, "No existe " .. name .. " en " .. current:GetFullName())
		current = child
	end
	return current
end

-- require sin la caché de Studio (ver la skill de modelos 3D). Los require internos del módulo sí
-- usan la caché.
function Anim.freshRequire(path: string): any
	local module = Anim.find(path)
	assert(module:IsA("ModuleScript"), path .. " no es un ModuleScript")
	local copy = module:Clone()
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	assert(ok, result)
	return result
end

function Anim.clear()
	local folder = Workspace:FindFirstChild(FOLDER)
	if folder then
		folder:Destroy()
	end
end

local function normalizeId(id: string | number): string
	local text = tostring(id)
	if string.match(text, "^%d+$") then
		return "rbxassetid://" .. text
	end
	return text
end

-- ===== Rigs =====

-- Deja el rig listo para animarlo en modo edición: solo la raíz anclada (si todo está anclado, la
-- animación no mueve nada) y un Animator.
local function prepare(rig: Model): Model
	local root = rig:FindFirstChild("HumanoidRootPart") or rig.PrimaryPart
	assert(root and root:IsA("BasePart"), rig.Name .. " no tiene HumanoidRootPart ni PrimaryPart")
	rig.PrimaryPart = root
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == root
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant.Enabled = false
		end
	end
	local holder: Instance? = rig:FindFirstChildOfClass("Humanoid") or rig:FindFirstChildOfClass("AnimationController")
	if not holder then
		local controller = Instance.new("AnimationController")
		controller.Parent = rig
		holder = controller
	end
	if not (holder :: Instance):FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = holder
	end
	return rig
end

local function animatorOf(rig: Model): Animator
	local holder = rig:FindFirstChildOfClass("Humanoid") or rig:FindFirstChildOfClass("AnimationController")
	local animator = holder and holder:FindFirstChildOfClass("Animator")
	assert(animator, rig.Name .. " no tiene Animator (usa los constructores de rig de Anim)")
	return animator :: Animator
end

-- Mono o jefe de MonkeyModels a escala 1 (como se anima, ver docs/ANIMACIONES.md). Solo en el place
-- de la Isla con Rojo conectado. options.scale = true usa la escala real de la especie o del jefe.
function Anim.monkeyRig(speciesOrBoss: string, options: { scale: boolean? }?): Model
	local MonkeyModels = Anim.freshRequire("ServerScriptService.Server.Monkeys.MonkeyModels")
	local Monkeys = Anim.freshRequire("ReplicatedStorage.Shared.Data.Monkeys")
	local Bosses = Anim.freshRequire("ReplicatedStorage.Shared.Data.Bosses")
	local species, bossId = speciesOrBoss, nil
	local look
	local boss = Bosses[speciesOrBoss]
	if boss then
		species, bossId = boss.baseSpecies, speciesOrBoss
		look = table.clone(Monkeys[species])
		look.name, look.scale = boss.name, boss.scale
		look.bodyColor, look.faceColor = boss.bodyColor, boss.faceColor
	else
		assert(Monkeys[species], "No existe la especie ni el jefe " .. speciesOrBoss)
		look = table.clone(Monkeys[species])
	end
	if not (options and options.scale) then
		look.scale = 1
	end
	local rig = MonkeyModels.build(species, look, Vector3.zero, bossId)
	rig.Name = "Rig_" .. speciesOrBoss
	return prepare(rig)
end

-- Personaje de jugador por defecto ("R15" o "R6"). El R15 que crea Studio lleva articulaciones
-- nuevas (AnimationConstraint) en vez de Motor6D: las animaciones se aplican igual. El R6 tiene las
-- mismas piezas que los monos (Torso, Head, Right Arm…): sirve para ver una animación de mono en un
-- place sin MonkeyModels (el Lobby), aunque las proporciones no son las del mono.
function Anim.playerRig(rigType: string?): Model
	local kind = rigType or "R15"
	-- Sin colores sale negro y las poses no se leen: piel clara y torso azul, como el maniquí de la
	-- vista previa de modelos.
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(215, 185, 150)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = Color3.fromRGB(90, 140, 220)
	description.LeftLegColor = Color3.fromRGB(70, 75, 90)
	description.RightLegColor = Color3.fromRGB(70, 75, 90)
	local rig = Players:CreateHumanoidModelFromDescription(description, (Enum.HumanoidRigType :: any)[kind])
	rig.Name = "Rig_" .. kind
	return prepare(rig)
end

-- Un rig que ya está en el place (se clona; el original no se toca).
function Anim.placeRig(path: string): Model
	local original = Anim.find(path)
	assert(original:IsA("Model"), path .. " no es un Model")
	return prepare((original :: Model):Clone())
end

-- De qué pieza cuelga cada pieza articulada: { [hijo] = padre }. Vale para Motor6D y para
-- AnimationConstraint (R15 nuevo). Es la jerarquía que deben seguir las Pose.
function Anim.hierarchy(rig: Model): { [string]: string }
	local parents: { [string]: string } = {}
	for _, joint in rig:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			parents[joint.Part1.Name] = joint.Part0.Name
		elseif joint:IsA("AnimationConstraint") then
			local a0 = (joint :: any).Attachment0 :: Attachment?
			local a1 = (joint :: any).Attachment1 :: Attachment?
			if a0 and a1 and a0.Parent and a1.Parent then
				parents[(a1.Parent :: Instance).Name] = (a0.Parent :: Instance).Name
			end
		end
	end
	return parents
end

-- ===== Spec <-> KeyframeSequence =====

local RESERVED = { t = true, reposo = true, marcador = true, easing = true, direction = true }

local function poseCFrame(value: { any }?): CFrame
	if not value then
		return CFrame.identity
	end
	local rx, ry, rz = value[1] or 0, value[2] or 0, value[3] or 0
	local px, py, pz = value[4] or 0, value[5] or 0, value[6] or 0
	return CFrame.new(px, py, pz) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
end

-- Piezas que anima un spec (las que aparecen en algún fotograma), ordenadas.
local function animatedParts(spec: any): { string }
	local seen, list = {}, {}
	for _, frame in spec.keyframes do
		for key, value in frame do
			if not RESERVED[key] and type(value) == "table" and not seen[key] then
				seen[key] = true
				table.insert(list, key)
			end
		end
	end
	table.sort(list)
	return list
end

-- Crea una KeyframeSequence a partir de un spec. Con "rig" se saca la jerarquía de sus
-- articulaciones y se comprueba que las piezas existen; sin él hay que pasar spec.hierarchy.
function Anim.build(spec: any, rig: Model?): KeyframeSequence
	local parents: { [string]: string } = spec.hierarchy or (rig and Anim.hierarchy(rig)) or {}
	assert(next(parents), "Anim.build necesita el rig o spec.hierarchy para saber de qué cuelga cada pieza")
	local parts = animatedParts(spec)
	for _, name in parts do
		assert(parents[name], `"{name}" no es una pieza articulada del rig (¿nombre mal escrito?)`)
	end

	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = spec.name or "Animacion"
	sequence.Loop = spec.loop == true
	sequence.Priority = (Enum.AnimationPriority :: any)[spec.priority or "Action"]

	for _, frame in spec.keyframes do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = frame.t
		local poses: { [string]: Pose } = {}
		-- Las poses que solo dan la jerarquía (raíz, torso sin animar) llevan peso 0: no tocan esa
		-- articulación.
		local function poseOf(name: string): Pose
			local existing = poses[name]
			if existing then
				return existing
			end
			local pose = Instance.new("Pose")
			pose.Name = name
			pose.Weight = 0
			poses[name] = pose
			local parentName = parents[name]
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
			pose.CFrame = poseCFrame(value)
			local easing = (value and value.easing) or frame.easing or spec.easing or "Linear"
			local direction = (value and value.direction) or frame.direction or spec.direction or "In"
			pose.EasingStyle = (Enum.PoseEasingStyle :: any)[easing]
			pose.EasingDirection = (Enum.PoseEasingDirection :: any)[direction]
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

-- Baja una animación publicada ("rbxassetid://…" o el número). Solo funciona con las que puede
-- abrir quien tiene Studio abierto (las del dueño del juego).
function Anim.download(id: string | number): KeyframeSequence
	local assetId = normalizeId(id)
	local ok, result = pcall(function()
		return KeyframeSequenceProvider:GetKeyframeSequenceAsync(assetId)
	end)
	assert(ok, `No se pudo bajar {assetId}: {result} (¿es de otro dueño o no es una animación?)`)
	assert(
		typeof(result) == "Instance" and result:IsA("KeyframeSequence"),
		`{assetId} no es una KeyframeSequence (si se hizo con curvas, ábrela en el Animation Editor y`
			.. ` guárdala con fotogramas clave)`
	)
	result.Name = string.match(assetId, "%d+$") or "Descargada"
	return result
end

local function sortedKeyframes(sequence: KeyframeSequence): { Keyframe }
	local keyframes = sequence:GetKeyframes() :: { any }
	table.sort(keyframes, function(a, b)
		return a.Time < b.Time
	end)
	return keyframes :: { Keyframe }
end

local function num(value: number): string
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	if text == "-0" then
		return "0"
	end
	return text
end

local function quoteKey(name: string): string
	if string.match(name, "^[%a_][%w_]*$") then
		return name
	end
	return `["{name}"]`
end

-- Convierte una KeyframeSequence en el texto de un spec (para leer una animación publicada o hecha
-- a mano, retocarla y reconstruirla con Anim.build). Solo se vuelcan las poses con peso.
function Anim.dump(sequence: KeyframeSequence): string
	local keyframes = sortedKeyframes(sequence)
	-- El easing más usado va como valor por defecto del spec; las poses distintas lo llevan dentro.
	local easingCount: { [string]: number } = {}
	local directionCount: { [string]: number } = {}
	local animated: { [string]: boolean } = {}
	for _, keyframe in keyframes do
		for _, pose in keyframe:GetDescendants() do
			if pose:IsA("Pose") and pose.Weight > 0 then
				animated[pose.Name] = true
				easingCount[pose.EasingStyle.Name] = (easingCount[pose.EasingStyle.Name] or 0) + 1
				directionCount[pose.EasingDirection.Name] = (directionCount[pose.EasingDirection.Name] or 0) + 1
			end
		end
	end
	local function mostUsed(counts: { [string]: number }, fallback: string): string
		local best, bestCount = fallback, -1
		for name, count in counts do
			if count > bestCount then
				best, bestCount = name, count
			end
		end
		return best
	end
	local easing = mostUsed(easingCount, "Linear")
	local direction = mostUsed(directionCount, "In")
	local animatedCount = 0
	for _ in animated do
		animatedCount += 1
	end

	local lines = {
		"{",
		`	name = "{sequence.Name}",`,
		`	loop = {sequence.Loop},`,
		`	priority = "{sequence.Priority.Name}",`,
		`	easing = "{easing}",`,
		`	direction = "{direction}",`,
		"	keyframes = {",
	}
	for _, keyframe in keyframes do
		local entries: { string } = {}
		local named: { Pose } = {}
		local allRest = true
		for _, pose in keyframe:GetDescendants() do
			if pose:IsA("Pose") and pose.Weight > 0 then
				table.insert(named, pose)
				if pose.CFrame ~= CFrame.identity then
					allRest = false
				end
			end
		end
		table.sort(named, function(a, b)
			return a.Name < b.Name
		end)
		local rest = allRest and #named == animatedCount
		for _, pose in named do
			local extra = ""
			if pose.EasingStyle.Name ~= easing then
				extra ..= `, easing = "{pose.EasingStyle.Name}"`
			end
			if pose.EasingDirection.Name ~= direction then
				extra ..= `, direction = "{pose.EasingDirection.Name}"`
			end
			if rest and extra == "" then
				continue
			end
			local rx, ry, rz = pose.CFrame:ToEulerAnglesXYZ()
			local values = { num(math.deg(rx)), num(math.deg(ry)), num(math.deg(rz)) }
			local p = pose.CFrame.Position
			if p.Magnitude > 1e-3 then
				table.insert(values, num(p.X))
				table.insert(values, num(p.Y))
				table.insert(values, num(p.Z))
			end
			table.insert(entries, quoteKey(pose.Name) .. " = { " .. table.concat(values, ", ") .. extra .. " }")
		end
		if rest then
			table.insert(entries, 1, "reposo = true")
		end
		for _, marker in keyframe:GetMarkers() do
			table.insert(entries, `marcador = "{marker.Name}"`)
		end
		table.insert(entries, 1, `t = {num(keyframe.Time)}`)
		table.insert(lines, "		{ " .. table.concat(entries, ", ") .. " },")
	end
	table.insert(lines, "	},")
	table.insert(lines, "}")
	return table.concat(lines, "\n")
end

-- ===== Reproducir en modo edición =====

local function animationIdOf(source: any): string
	if typeof(source) == "Instance" then
		assert(source:IsA("KeyframeSequence"), "Solo se pueden reproducir KeyframeSequence")
		-- Id temporal de Studio. Depende del contenido: si cambias la secuencia, sale otro id, así que
		-- se registra cada vez (es barato).
		return KeyframeSequenceProvider:RegisterKeyframeSequence(source)
	end
	return normalizeId(source)
end

-- Carga "source" (KeyframeSequence, id publicado o id temporal) en el rig y la deja sonando a
-- velocidad 0, lista para fijar instantes con poseAt. Devuelve la pista.
function Anim.load(rig: Model, source: any, options: { keepOthers: boolean? }?): AnimationTrack
	local animator = animatorOf(rig)
	if not (options and options.keepOthers) then
		for _, playing in animator:GetPlayingAnimationTracks() do
			playing:Stop(0)
		end
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = animationIdOf(source)
	local track = animator:LoadAnimation(animation)
	track:Play(0, 1, 0)
	-- La pista se carga de forma asíncrona: hasta entonces Length vale 0 y no se mueve nada.
	local started = os.clock()
	while track.Length == 0 and os.clock() - started < LOAD_TIMEOUT do
		task.wait(0.05)
	end
	assert(track.Length > 0, `La animación {animation.AnimationId} no cargó (¿id mal o de otro dueño?)`)
	return track
end

-- Congela el rig en el instante "time" de la pista (o de varias, si se cargaron con keepOthers).
function Anim.poseAt(rig: Model, time: number)
	local animator = animatorOf(rig)
	for _, playing in animator:GetPlayingAnimationTracks() do
		local length = playing.Length
		-- Justo al final una pista sin bucle se para y el rig vuelve a la pose de reposo: se queda un
		-- milisegundo antes.
		playing.TimePosition = if playing.Looped and length > 0 then time % length else math.min(time, length - 0.001)
	end
	animator:StepAnimations(0)
end

local function visibleParts(model: Model): { BasePart }
	local list = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			table.insert(list, descendant)
		end
	end
	return list
end

local CORNERS = {}
for _, x in { -1, 1 } do
	for _, y in { -1, 1 } do
		for _, z in { -1, 1 } do
			table.insert(CORNERS, Vector3.new(x, y, z))
		end
	end
end

-- Lo más bajo del modelo (esquinas de las cajas: en óvalos y bolas da un poco de más).
local function lowestPoint(parts: { BasePart }): number
	local lowest = math.huge
	for _, part in parts do
		local half = part.Size / 2
		for _, corner in CORNERS do
			lowest = math.min(lowest, (part.CFrame * (half * corner)).Y)
		end
	end
	return lowest
end

-- Avisos sobre la secuencia: bucles que no cierran, acciones que no empiezan o acaban en reposo,
-- piezas que el rig no tiene.
function Anim.check(sequence: KeyframeSequence, rig: Model?): { string }
	local warnings: { string } = {}
	local keyframes = sortedKeyframes(sequence)
	if #keyframes == 0 then
		return { "La secuencia no tiene fotogramas" }
	end
	local function posesOf(keyframe: Keyframe): { [string]: CFrame }
		local result = {}
		for _, pose in keyframe:GetDescendants() do
			if pose:IsA("Pose") and pose.Weight > 0 then
				result[pose.Name] = pose.CFrame
			end
		end
		return result
	end
	local function angleBetween(a: CFrame, b: CFrame): number
		local _, angle = (a:Inverse() * b):ToAxisAngle()
		return math.deg(math.abs(angle))
	end
	local first, last = posesOf(keyframes[1]), posesOf(keyframes[#keyframes])
	if sequence.Loop then
		for name, frame in first do
			local other = last[name]
			if other and angleBetween(frame, other) > 1 then
				table.insert(warnings, `Bucle que no cierra: {name} difiere {round(angleBetween(frame, other), 0)}° entre el primer y el último fotograma`)
			elseif not other then
				table.insert(warnings, `Bucle: {name} está en el primer fotograma y no en el último`)
			end
		end
	else
		for which, poses in { empieza = first, acaba = last } do
			for name, frame in poses do
				local angle = angleBetween(frame, CFrame.identity)
				if angle > 1 or frame.Position.Magnitude > 0.01 then
					table.insert(
						warnings,
						`Acción que no {which} en reposo: {name} ({round(angle, 0)}°). Bien solo si es a propósito`
							.. " (Death, o un disparo que parte de la pose Hold)"
					)
				end
			end
		end
	end
	if keyframes[1].Time > 0.001 then
		table.insert(warnings, `El primer fotograma está en {round(keyframes[1].Time)} s, no en 0`)
	end
	if rig then
		local parents = Anim.hierarchy(rig)
		local missing = {}
		for _, keyframe in keyframes do
			for _, pose in keyframe:GetDescendants() do
				if pose:IsA("Pose") and pose.Weight > 0 and not parents[pose.Name] and not missing[pose.Name] then
					missing[pose.Name] = true
					table.insert(warnings, `{pose.Name} no es una pieza articulada de {rig.Name}: esa pose no hará nada`)
				end
			end
		end
	end
	return warnings
end

-- ===== Vista previa =====

-- Rótulo en el suelo, inclinado hacia la cámara. Un BillboardGui no sale en screen_capture; una
-- SurfaceGui sobre una pieza sí.
local function label(folder: Instance, position: Vector3, towardCamera: Vector3, text: string, width: number)
	local plate = Instance.new("Part")
	plate.Name = "Rotulo"
	plate.Size = Vector3.new(width, width * 0.22, 0.05)
	plate.CFrame = CFrame.lookAt(position, position + towardCamera + Vector3.new(0, 0.4, 0))
	plate.Transparency = 1
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0
	textLabel.Parent = gui
	gui.Parent = plate
	plate.Parent = folder
end

local function ensureFolder(keep: boolean?): Folder
	if not keep then
		Anim.clear()
	end
	local folder = Workspace:FindFirstChild(FOLDER) :: Folder?
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = FOLDER
		newFolder.Parent = Workspace
		folder = newFolder
	end
	return folder :: Folder
end

-- Pone en la zona de vista previa una tira de copias del rig, cada una congelada en un instante de
-- la animación "source" (KeyframeSequence o id), y devuelve un JSON con cámaras y avisos.
-- options:
--   times = { 0, 0.12, … }  instantes (por defecto, los de los fotogramas clave, o 6 repartidos)
--   view = "perfil" | "frente"  (perfil por defecto: los giros en X, los más habituales, se ven de lado)
--   under = id o KeyframeSequence  otra animación debajo (p. ej. Walk bajo un Attack que solo mueve
--     el brazo), como en el juego
--   keep = true  no borra lo que ya hubiera (para comparar dos versiones, con offset)
--   offset = Vector3  desplaza la tira (p. ej. Vector3.new(0, 0, 25) para ponerla al lado)
function Anim.show(rig: Model, source: any, options: any?): string
	local opts = options or {}
	local folder = ensureFolder(opts.keep)
	local sequence: KeyframeSequence? = if typeof(source) == "Instance" then source else nil

	-- Instantes.
	local times: { number } = opts.times
	local length = 0
	if sequence then
		local keyframes = sortedKeyframes(sequence)
		length = if #keyframes > 0 then keyframes[#keyframes].Time else 0
		if not times then
			times = {}
			for _, keyframe in keyframes do
				table.insert(times, keyframe.Time)
			end
		end
	end
	assert(times or source, "Sin animación (animaciones por código) hay que pasar options.times")
	if not times then
		-- Sin la secuencia no sabemos dónde están los fotogramas clave: carga la pista para ver su largo.
		local probe = rig:Clone()
		probe.Parent = folder
		length = Anim.load(probe, source).Length
		probe:Destroy()
		times = {}
		for i = 0, 5 do
			table.insert(times, round(length * i / 5))
		end
	end
	local markers: { [number]: string } = {}
	if sequence then
		for _, keyframe in sequence:GetKeyframes() do
			for _, marker in (keyframe :: Keyframe):GetMarkers() do
				markers[round(keyframe.Time)] = marker.Name
			end
		end
	end

	-- Tamaño del rig en reposo, apoyado en el suelo. Se mide una copia dentro del Workspace: fuera de
	-- él las articulaciones no se resuelven y las piezas quedan unas décimas desplazadas.
	rig:PivotTo(CFrame.new(ORIGIN))
	local probe = if opts.make then opts.make() else rig:Clone()
	probe:PivotTo(CFrame.new(ORIGIN))
	probe.Parent = folder
	local restBox, restSize = probe:GetBoundingBox()
	local restLowest = lowestPoint(visibleParts(probe))
	probe:Destroy()
	local lift = ORIGIN.Y - restLowest
	local front = opts.view == "frente"
	-- Perfil: cámara en -X mirando a +X, la tira avanza hacia +Z (que en pantalla va a la derecha).
	-- Frente: cámara en -Z (delante del mono, que mira a -Z), la tira avanza hacia -X.
	local stepAxis = if front then Vector3.new(-1, 0, 0) else Vector3.new(0, 0, 1)
	local spacing = math.max(restSize.X, restSize.Y, restSize.Z) * 1.25 + 1
	local base = ORIGIN + (opts.offset or Vector3.zero)
	local rigOffset = Vector3.new(ORIGIN.X - restBox.Position.X, lift, ORIGIN.Z - restBox.Position.Z)

	if not folder:FindFirstChild("Base") then
		local floor = Instance.new("Part")
		floor.Name = "Base"
		floor.Size = Vector3.new(160, 1, 160)
		floor.Position = ORIGIN - Vector3.new(0, 0.5, 0)
		floor.Color = Color3.fromRGB(150, 150, 150)
		floor.Material = Enum.Material.SmoothPlastic
		floor.Anchored = true
		floor.CanCollide = false
		floor.CanQuery = false
		floor.CanTouch = false
		floor.Parent = folder
	end

	local frames = {}
	local warnings: { string } = if sequence then Anim.check(sequence, rig) else {}
	local view = if front then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0) -- hacia donde mira la cámara
	for index, time in times do
		local copy = if opts.make then opts.make() else rig:Clone()
		copy.Name = `{rig.Name}_{round(time)}s`
		copy:PivotTo(CFrame.new(base + stepAxis * (index - 1) * spacing + rigOffset) * rig:GetPivot().Rotation)
		copy.Parent = folder
		if opts.pose then
			opts.pose(copy, time)
		else
			if opts.under then
				Anim.load(copy, opts.under)
				Anim.load(copy, source, { keepOthers = true })
			else
				Anim.load(copy, source)
			end
			Anim.poseAt(copy, time)
		end
		local ground = lowestPoint(visibleParts(copy)) - base.Y
		local marker = markers[round(time)]
		local text = `{round(time)} s` .. (if marker then ` · {marker}` else "")
		local depth = if front then restSize.Z else restSize.X
		local labelWidth = math.min(spacing * 0.85, 5)
		local footing = base + stepAxis * (index - 1) * spacing
		label(folder, footing - view * (depth / 2 + 0.8) + Vector3.new(0, labelWidth * 0.12, 0), -view, text, labelWidth)
		local center = base + stepAxis * (index - 1) * spacing + Vector3.new(0, restSize.Y / 2, 0)
		local close = math.max(restSize.X, restSize.Y, restSize.Z) * 1.4 + 3
		table.insert(frames, {
			t = round(time),
			marcador = marker,
			-- Lo más bajo del modelo respecto al suelo: negativo = se hunde, positivo = flota.
			suelo = round(ground),
			camara = { position = vector(center - view * close + Vector3.new(0, restSize.Y * 0.2, 0)), lookAt = vector(center) },
		})
		-- Con margen: la medida por esquinas exagera en los óvalos girados (una pata a 25° "baja" unas
		-- décimas que no se ven).
		if ground < -0.25 then
			table.insert(warnings, `En {round(time)} s el modelo se hunde {round(-ground)} studs en el suelo`)
		elseif ground > 0.3 then
			table.insert(warnings, `En {round(time)} s el modelo flota {round(ground)} studs sobre el suelo (bien si salta)`)
		end
	end

	-- Cámara que abarca toda la tira. La captura no siempre es apaisada (a veces casi cuadrada): se
	-- cuenta con unos 35° de semiángulo en horizontal.
	local count = #times
	local stripCenter = base + stepAxis * ((count - 1) * spacing / 2) + Vector3.new(0, restSize.Y / 2, 0)
	local width = count * spacing
	local distance = math.max((width / 2) / math.tan(math.rad(35)), restSize.Y / math.tan(math.rad(30))) + spacing / 2
	local cameraPosition = stripCenter - view * distance + Vector3.new(0, distance * 0.15, 0)

	-- La cámara de Studio también, para que el usuario lo encuentre.
	Workspace.CurrentCamera.CFrame = CFrame.lookAt(cameraPosition, stripCenter)
	game:GetService("Selection"):Set({})

	return HttpService:JSONEncode({
		rig = rig.Name,
		animacion = if sequence then sequence.Name elseif source then tostring(source) else "por código",
		duracion = round(length),
		bucle = if sequence then sequence.Loop else nil,
		tamanoRig = vector(restSize),
		vista = if front then "frente" else "perfil",
		tira = { position = vector(cameraPosition), lookAt = vector(stripCenter) },
		fotogramas = frames,
		avisos = warnings,
	})
end

-- Lo mismo para lo que se anima por código (mascotas de PetModels): "make" construye un modelo nuevo
-- en cada instante (no vale clonar: el módulo solo mueve los modelos que construyó él) y "pose" lo
-- coloca en el instante dado. Usa la misma copia del módulo para las dos cosas.
function Anim.showCode(make: () -> Model, pose: (Model, number) -> (), times: { number }, options: any?): string
	local opts = table.clone(options or {})
	opts.make, opts.pose, opts.times = make, pose, times
	return Anim.show(make(), nil, opts)
end

-- Un solo rig congelado en "time" (para acercar la cámara a un detalle). Devuelve la cámara.
function Anim.showOne(rig: Model, source: any, time: number, options: any?): string
	local opts = table.clone(options or {})
	opts.times = { time }
	return Anim.show(rig, source, opts)
end

-- ===== Medir sin ver =====

local LIMB_GROUPS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg", "Tail" }

-- En el R15 del jugador cada pieza va por su cuenta: se miden manos, pies, espinillas (rodillas en
-- el suelo) y la cabeza.
local R15_GROUPS = { "LowerTorso", "Head", "RightHand", "LeftHand", "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot" }

-- Pieza articulada (de LIMB_GROUPS) a la que va pegada cada pieza visible, siguiendo las
-- WeldConstraint de MonkeyModels (antebrazo → brazo, pie → muslo, punta de la cola → cola…).
local function limbGroups(rig: Model): { [string]: { BasePart } }
	if rig:FindFirstChild("LowerTorso") then
		local groups: { [string]: { BasePart } } = {}
		for _, name in R15_GROUPS do
			local part = rig:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				groups[name] = { part }
			end
		end
		return groups
	end
	local owner: { [BasePart]: BasePart } = {}
	for _, weld in rig:GetDescendants() do
		if weld:IsA("WeldConstraint") and weld.Part0 and weld.Part1 then
			owner[weld.Part1] = weld.Part0
		end
	end
	local groups: { [string]: { BasePart } } = {}
	for _, part in visibleParts(rig) do
		if part ~= rig.PrimaryPart then
			local current, guard = part, 0
			while owner[current] and not table.find(LIMB_GROUPS, current.Name) and guard < 10 do
				current, guard = owner[current], guard + 1
			end
			local group = if table.find(LIMB_GROUPS, current.Name) then current.Name else "Torso"
			groups[group] = groups[group] or {}
			table.insert(groups[group], part)
		end
	end
	return groups
end

-- Mide una animación de mono por números, sin capturas (cuando screen_capture no responde o para
-- afinar): en cada instante (por defecto, los fotogramas clave), lo más bajo de cada extremidad
-- respecto al suelo en reposo (negativo = se hunde; un brazo a 1,2 está levantado), la altura de la
-- punta de la cola y la altura y el avance de la cabeza. Devuelve texto, una línea por instante.
-- Abreviaturas: BD/BI brazo derecho/izquierdo, PD/PI pierna. Torso, cabeza y cola solo salen si
-- tocan el suelo. Con el R15 del jugador: MD/MI manos, ED/EI espinillas, PD/PI pies, y dónde
-- quedan la mano derecha y la cabeza.
function Anim.measure(rig: Model, source: any, times: { number }?): string
	local copy = rig:Clone()
	copy:PivotTo(CFrame.new(ORIGIN + Vector3.new(0, 200, 400)))
	copy.Parent = Workspace
	local groups = limbGroups(copy)
	local function lows(): ({ [string]: number }, number)
		local result, all = {}, math.huge
		for group, parts in groups do
			result[group] = lowestPoint(parts)
			all = math.min(all, result[group])
		end
		return result, all
	end
	local _, floorY = lows()
	local tailTip = copy:FindFirstChild("TailTip", true) :: BasePart?
	local root = copy.PrimaryPart :: BasePart
	local track = Anim.load(copy, source)
	local list = times
	if not list then
		list = {}
		if typeof(source) == "Instance" then
			for _, keyframe in sortedKeyframes(source) do
				table.insert(list, keyframe.Time)
			end
		else
			for i = 0, 5 do
				table.insert(list, round(track.Length * i / 5))
			end
		end
	end
	local short = {
		["Right Arm"] = "BD",
		["Left Arm"] = "BI",
		["Right Leg"] = "PD",
		["Left Leg"] = "PI",
		RightHand = "MD",
		LeftHand = "MI",
		RightLowerLeg = "ED",
		LeftLowerLeg = "EI",
		RightFoot = "PD",
		LeftFoot = "PI",
	}
	local order = if copy:FindFirstChild("LowerTorso") then R15_GROUPS else LIMB_GROUPS
	local rows = {}
	for _, time in list :: { number } do
		Anim.poseAt(copy, time)
		local result = lows()
		local entries = {}
		for _, group in order do
			local value = result[group]
			if value then
				value -= floorY
				if short[group] then
					table.insert(entries, string.format("%s %.2f", short[group], value))
				elseif value < 0.02 then
					table.insert(entries, string.format("%s %.2f", group, value))
				end
			end
		end
		local base = floorY - root.Position.Y
		if tailTip then
			local tip = root.CFrame:PointToObjectSpace(tailTip.Position)
			table.insert(entries, string.format("cola(alto %.1f, atrás %.1f)", tip.Y - base, tip.Z))
		end
		local hand = copy:FindFirstChild("RightHand") :: BasePart?
		if hand then
			local at = root.CFrame:PointToObjectSpace(hand.Position)
			table.insert(entries, string.format("manoD(alto %.1f, delante %.1f, lado %.1f)", at.Y - base, -at.Z, at.X))
		end
		local head = copy:FindFirstChild("Head") :: BasePart?
		if head then
			local at = root.CFrame:PointToObjectSpace(head.Position)
			table.insert(entries, string.format("cabeza(alto %.1f, delante %.1f)", at.Y - base, -at.Z))
		end
		table.insert(rows, string.format("t=%.2f ", time) .. table.concat(entries, " "))
	end
	copy:Destroy()
	return table.concat(rows, "\n")
end

-- Mueve la cámara de Studio.
function Anim.look(position: { number }, lookAt: { number })
	Workspace.CurrentCamera.CFrame =
		CFrame.lookAt(Vector3.new(position[1], position[2], position[3]), Vector3.new(lookAt[1], lookAt[2], lookAt[3]))
end

-- ===== Guardar en el place =====

-- Guarda la secuencia donde el Animation Editor la encuentra (ServerStorage.RBX_ANIMSAVES.<rig>) o
-- en "parentPath", sustituyendo la que se llame igual, y la selecciona en el Explorador para que el
-- usuario la publique (clic derecho > Guardar en Roblox). Con registro de deshacer.
function Anim.save(sequence: KeyframeSequence, rigNameOrPath: string): string
	local ChangeHistoryService = game:GetService("ChangeHistoryService")
	local recording = ChangeHistoryService:TryBeginRecording("Guardar animación " .. sequence.Name)
	local parent: Instance
	if string.find(rigNameOrPath, "%.") then
		parent = Anim.find(rigNameOrPath)
	else
		local ServerStorage = game:GetService("ServerStorage")
		local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
		if not saves then
			saves = Instance.new("Model")
			saves.Name = "RBX_ANIMSAVES"
			saves.Parent = ServerStorage
		end
		local rigFolder = (saves :: Instance):FindFirstChild(rigNameOrPath)
		if not rigFolder then
			rigFolder = Instance.new("ObjectValue")
			rigFolder.Name = rigNameOrPath
			rigFolder.Parent = saves
		end
		parent = rigFolder :: Instance
	end
	local old = parent:FindFirstChild(sequence.Name)
	if old and old ~= sequence then
		old:Destroy()
	end
	sequence.Parent = parent
	game:GetService("Selection"):Set({ sequence })
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	return sequence:GetFullName()
end

-- ===== Código del encargo a partir de aquí =====
