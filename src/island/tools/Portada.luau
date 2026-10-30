--!strict
-- Escena de las portadas e iconos (art/portada/): los 4 roles con su mejor equipo delante, los 4 jefes
-- detrás, el volcán en erupción al fondo y rayos. Corre en modo edición, en el Studio de la Isla:
--
--   local m = game.ServerStorage.Tools.Portada:Clone() -- el Clone evita la caché de require
--   local P = require(m)
--   P.build("principal")   -- o "icono"; construye Workspace.Portada y deja la cámara en la toma
--   P.clear()              -- la quita y devuelve la iluminación
--
-- El equipo de cada jugador está en EQUIPOS: se cambia aquí (id de traje o de armadura, aspecto del arma).
-- Es un diorama quieto: las poses giran las uniones del R15, no hay AnimationTrack.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArmorModels = require(Shared:WaitForChild("ArmorModels")) :: any
local WeaponTools = require(Shared:WaitForChild("WeaponTools")) :: any
local Bosses = require(Shared.Data.Bosses) :: any
local Monkeys = require(Shared.Data.Monkeys) :: any
local MonkeyModels = require(ServerScriptService.Combat.Monkeys.MonkeyModels) :: any

local Portada = {}

-- Lejos de la isla, para no tocar nada de ella.
local ORIGEN = Vector3.new(4000, 0, 0)
local NOMBRE = "Portada"

type Equipo = {
	rol: string,
	armadura: string?, -- armadura fabricada (BY_GRADE); si no, "traje"
	traje: string?,
	arma: string?, -- id de arma de Data/Weapons; por defecto la de su rol al nivel máximo
	aspecto: string?, -- aspecto del arma (Data/Cosmetics "WeaponSkin")
	piel: Color3,
	pantalon: Color3,
	x: number, -- a lo ancho, desde el centro (studs)
	z: number, -- hacia la cámara (+)
	giro: number, -- grados sobre el eje vertical; 0 mira a la cámara
	pose: string,
}

-- Cazador al centro y los demás a los lados, escalonados. Todos al grado máximo.
local EQUIPOS: { Equipo } = {
	{
		rol = "Guerrero",
		traje = "TitanKingOutfit",
		aspecto = "TitanKingMace",
		piel = Color3.fromRGB(205, 150, 110),
		pantalon = Color3.fromRGB(70, 47, 30),
		x = -15,
		z = 4,
		giro = 14,
		pose = "mazo",
	},
	{
		rol = "Cazador",
		armadura = "VolcanicArmor",
		piel = Color3.fromRGB(230, 180, 140),
		pantalon = Color3.fromRGB(62, 58, 60),
		x = -2,
		z = 12,
		giro = -6,
		pose = "arco",
	},
	{
		rol = "Mago",
		traje = "BlueFireInvokerOutfit",
		aspecto = "SulfurStaff",
		piel = Color3.fromRGB(160, 110, 80),
		pantalon = Color3.fromRGB(64, 54, 112),
		x = 11,
		z = 6,
		giro = -14,
		pose = "baston",
	},
	{
		rol = "Medico",
		traje = "CeibaOfLifeOutfit",
		aspecto = "CeibaBlowgun",
		piel = Color3.fromRGB(190, 135, 95),
		pantalon = Color3.fromRGB(112, 86, 54),
		x = 22,
		z = -2,
		giro = -22,
		pose = "cerbatana",
	},
}

-- Jefes de izquierda a derecha, el de Ceniza (el final, el más grande) en el centro.
local JEFES = {
	{ id = "OrangutanDelManglar", x = -34, z = -26, giro = 12 },
	{ id = "GorilaAlbino", x = -12, z = -34, giro = 6 },
	{ id = "GorilaDeCeniza", x = 10, z = -48, giro = 0 },
	{ id = "ChimpanceCaudillo", x = 36, z = -28, giro = -12 },
}

local TOMAS = {
	principal = { camara = Vector3.new(2, 9, 62), objetivo = Vector3.new(2, 11, -20) },
	icono = { camara = Vector3.new(-1, 7, 40), objetivo = Vector3.new(0, 8, -10) },
}

local function parte(
	padre: Instance,
	nombre: string,
	tamano: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparencia: number?
): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tamano
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparencia or 0
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Parent = padre
	return p
end

local function anclar(modelo: Instance)
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
end

-- ===================================== Fondo =====================================

local function cielo(carpeta: Folder)
	-- Un telón enorme con el degradado de la portada (gen.py): del morado nocturno al naranja del horizonte.
	local telon = parte(
		carpeta,
		"Cielo",
		Vector3.new(1800, 900, 2),
		CFrame.new(ORIGEN + Vector3.new(0, 300, -420)),
		Color3.new(1, 1, 1)
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 1
	gui.Parent = telon
	local marco = Instance.new("Frame")
	marco.Size = UDim2.fromScale(1, 1)
	marco.BorderSizePixel = 0
	marco.BackgroundColor3 = Color3.new(1, 1, 1)
	marco.Parent = gui
	local degradado = Instance.new("UIGradient")
	degradado.Rotation = 90
	degradado.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 4, 30)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(70, 16, 90)),
		ColorSequenceKeypoint.new(0.62, Color3.fromRGB(180, 40, 80)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(242, 84, 62)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 190, 110)),
	})
	degradado.Parent = marco

	local suelo = parte(
		carpeta,
		"Suelo",
		Vector3.new(600, 2, 400),
		CFrame.new(ORIGEN + Vector3.new(0, -1, -60)),
		Color3.fromRGB(58, 34, 40),
		Enum.Material.Slate
	)
	suelo.CastShadow = true
end

local BASALTO = Color3.fromRGB(104, 84, 92)
local OBSIDIANA = Color3.fromRGB(66, 50, 78)
local MAGMA = Color3.fromRGB(255, 110, 30)
local BRASA = Color3.fromRGB(255, 180, 60)

local function volcan(carpeta: Folder)
	local modelo = Instance.new("Model")
	modelo.Name = "Volcan"
	modelo.Parent = carpeta
	local centro = ORIGEN + Vector3.new(0, 0, -190)
	-- Cono de capas cuadradas (voxel): cada capa es más estrecha y está más alta.
	local capas = 14
	for i = 0, capas - 1 do
		local ancho = 120 - i * 6.6
		local alto = 5
		local color = if i % 3 == 0 then OBSIDIANA else BASALTO
		parte(
			modelo,
			`Capa{i}`,
			Vector3.new(ancho, alto, ancho),
			CFrame.new(centro + Vector3.new(0, 2.5 + i * alto, 0)),
			color,
			Enum.Material.Basalt
		)
		-- Una grieta de lava por capa, en una cara distinta, para que el cono arda por todas partes.
		local lado = (i % 4) * math.pi / 2
		local d = ancho / 2 + 0.1
		parte(
			modelo,
			`Grieta{i}`,
			Vector3.new(5, alto + 3, 0.8),
			CFrame.new(centro + Vector3.new(math.sin(lado) * d * 0.55, 2.5 + i * alto, math.cos(lado) * d))
				* CFrame.Angles(0, lado, 0.2 * (i % 2 * 2 - 1)),
			MAGMA,
			Enum.Material.Neon
		)
	end
	local cima = 2.5 + (capas - 1) * 5 + 3
	-- Lava en el cráter y la columna de erupción.
	parte(
		modelo,
		"Crater",
		Vector3.new(34, 3, 34),
		CFrame.new(centro + Vector3.new(0, cima, 0)),
		MAGMA,
		Enum.Material.Neon
	)
	for i = 1, 9 do
		local ancho = 20 - i * 1.4
		parte(
			modelo,
			`Columna{i}`,
			Vector3.new(ancho, 9, ancho),
			CFrame.new(centro + Vector3.new((i % 3 - 1) * 2, cima + 4 + i * 9, 0)),
			if i < 4 then BRASA else MAGMA,
			Enum.Material.Neon,
			0.1 + i * 0.05
		)
	end
	-- Nube de humo y ceniza.
	for i = 1, 14 do
		local a = i * 2.4
		local r = 18 + (i % 4) * 14
		local tam = 30 + (i % 3) * 16
		parte(
			modelo,
			`Humo{i}`,
			Vector3.new(tam, tam * 0.6, tam),
			CFrame.new(centro + Vector3.new(math.cos(a) * r, cima + 95 + (i % 5) * 9, math.sin(a) * r * 0.4)),
			Color3.fromRGB(40 + (i % 3) * 12, 30 + (i % 3) * 8, 44),
			Enum.Material.SmoothPlastic,
			0.12
		)
	end
	-- Bombas de lava con su estela, cayendo en diagonal.
	local bombas = {
		{ Vector3.new(-70, 150, -150), 7 },
		{ Vector3.new(-30, 190, -150), 5 },
		{ Vector3.new(60, 170, -150), 8 },
		{ Vector3.new(95, 120, -150), 5 },
		{ Vector3.new(30, 215, -150), 4 },
	}
	for i, bomba in bombas do
		local pos = ORIGEN + bomba[1]
		local tam = bomba[2] :: number
		local dir = Vector3.new(if i % 2 == 0 then -0.6 else 0.6, 1, 0).Unit
		parte(
			modelo,
			`Bomba{i}`,
			Vector3.one * tam,
			CFrame.new(pos) * CFrame.Angles(i, i * 2, i * 3),
			MAGMA,
			Enum.Material.Neon
		)
		parte(modelo, `Nucleo{i}`, Vector3.one * tam * 0.5, CFrame.new(pos), BRASA, Enum.Material.Neon)
		for k = 1, 6 do
			local t = tam * (0.9 + k * 0.7)
			parte(
				modelo,
				`Estela{i}_{k}`,
				Vector3.one * tam * (0.8 - k * 0.1),
				CFrame.new(pos + dir * t) * CFrame.Angles(k, k * 2, 0),
				if k < 3 then BRASA else MAGMA,
				Enum.Material.Neon,
				k * 0.12
			)
		end
	end
end

local function rayo(padre: Instance, nombre: string, desde: Vector3, hasta: Vector3, grosor: number)
	-- Zigzag de bloques de neón blanco azulado, con un halo más ancho y translúcido.
	local pasos = 7
	local previo = desde
	for i = 1, pasos do
		local t = i / pasos
		local punto = desde:Lerp(hasta, t)
		if i < pasos then
			punto += Vector3.new((if i % 2 == 0 then 1 else -1) * (10 + i * 2), 0, 0)
		end
		local largo = (punto - previo).Magnitude
		local cf = CFrame.lookAt((previo + punto) / 2, punto)
		parte(
			padre,
			`{nombre}_{i}`,
			Vector3.new(grosor, grosor, largo),
			cf,
			Color3.fromRGB(235, 245, 255),
			Enum.Material.Neon
		)
		parte(
			padre,
			`{nombre}_halo{i}`,
			Vector3.new(grosor * 3, grosor * 3, largo),
			cf,
			Color3.fromRGB(120, 170, 255),
			Enum.Material.Neon,
			0.7
		)
		previo = punto
	end
end

local function rayos(carpeta: Folder)
	local modelo = Instance.new("Model")
	modelo.Name = "Rayos"
	modelo.Parent = carpeta
	rayo(modelo, "R1", ORIGEN + Vector3.new(-48, 260, -170), ORIGEN + Vector3.new(-62, 8, -100), 1.6)
	rayo(modelo, "R2", ORIGEN + Vector3.new(58, 240, -170), ORIGEN + Vector3.new(48, 8, -90), 1.2)
end

-- ===================================== Jugadores =====================================

local function rigDe(equipo: Equipo): Model
	local descripcion = Instance.new("HumanoidDescription")
	descripcion.HeadColor = equipo.piel
	descripcion.TorsoColor = equipo.piel
	descripcion.LeftArmColor = equipo.piel
	descripcion.RightArmColor = equipo.piel
	descripcion.LeftLegColor = equipo.pantalon
	descripcion.RightLegColor = equipo.pantalon
	local rig = Players:CreateHumanoidModelFromDescription(descripcion, Enum.HumanoidRigType.R15)
	rig.Name = `Jugador_{equipo.rol}`
	return rig
end

-- Los R15 que crea Roblox llevan AnimationConstraint, no Motor6D, y en modo edición no se mueven solas.
-- Así que se posan a mano, con todo anclado: cada unión gira las piezas que cuelgan de ella (el miembro y
-- lo que lleva soldado: armadura, arma) alrededor de su punto de giro. Hay que anclar antes de posar.
local CUELGAN: { [string]: { string } } = {
	RightShoulder = { "RightUpperArm", "RightLowerArm", "RightHand" },
	RightElbow = { "RightLowerArm", "RightHand" },
	RightWrist = { "RightHand" },
	LeftShoulder = { "LeftUpperArm", "LeftLowerArm", "LeftHand" },
	LeftElbow = { "LeftLowerArm", "LeftHand" },
	LeftWrist = { "LeftHand" },
	Neck = { "Head" },
}

-- Las piezas soldadas (WeldConstraint o Weld) a "miembro", sin pasar a otro miembro del cuerpo.
local function soldadas(rig: Model, miembro: BasePart): { BasePart }
	local cuerpo: { [Instance]: boolean } = {}
	for _, hijo in rig:GetChildren() do
		if hijo:IsA("BasePart") then
			cuerpo[hijo] = true
		end
	end
	local vecinas: { [BasePart]: { BasePart } } = {}
	local function une(a: BasePart?, b: BasePart?)
		if a and b then
			vecinas[a] = vecinas[a] or {}
			vecinas[b] = vecinas[b] or {}
			table.insert(vecinas[a], b)
			table.insert(vecinas[b], a)
		end
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("WeldConstraint") or d:IsA("Weld") then
			une(d.Part0, d.Part1)
		end
	end
	local visto: { [BasePart]: boolean } = { [miembro] = true }
	local lista: { BasePart } = { miembro }
	local i = 1
	while i <= #lista do
		for _, otra in vecinas[lista[i]] or {} do
			if not visto[otra] and not cuerpo[otra] then
				visto[otra] = true
				table.insert(lista, otra)
			end
		end
		i += 1
	end
	return lista
end

-- Gira una unión del R15 "grados" sobre su reposo; los giros se apilan (hombro y luego codo).
local function gira(rig: Model, nombre: string, x: number, y: number?, z: number?)
	local union = rig:FindFirstChild(nombre, true)
	local miembros = CUELGAN[nombre]
	if not (union and union:IsA("AnimationConstraint") and miembros and union.Attachment0) then
		warn(`Portada: no se puede girar {nombre}`)
		return
	end
	local pivote = union.Attachment0.WorldCFrame
	local giro = pivote * CFrame.Angles(math.rad(x), math.rad(y or 0), math.rad(z or 0)) * pivote:Inverse()
	local partes: { BasePart } = {}
	for _, miembro in miembros do
		local pieza = rig:FindFirstChild(miembro)
		if pieza and pieza:IsA("BasePart") then
			for _, otra in soldadas(rig, pieza) do
				table.insert(partes, otra)
			end
		end
	end
	for _, pieza in partes do
		pieza.CFrame = giro * pieza.CFrame
	end
end

-- Hace rodar la mano y lo que lleva (el arma) sobre un eje del mundo que pasa por la mano: el arco, que
-- con el brazo adelantado apunta hacia delante, pasa a estar de pie.
local function rodaMano(rig: Model, lado: string, eje: Vector3, grados: number)
	local mano = rig:FindFirstChild(`{lado}Hand`)
	if not (mano and mano:IsA("BasePart")) then
		return
	end
	local giro = CFrame.new(mano.Position) * CFrame.fromAxisAngle(eje, math.rad(grados)) * CFrame.new(-mano.Position)
	for _, pieza in soldadas(rig, mano) do
		pieza.CFrame = giro * pieza.CFrame
	end
end

-- Con el brazo colgando, las armas apuntan hacia delante (su eje largo sale del mango a -Z); al subir el
-- brazo 90° hacia delante (X) quedan de pie. El giro Z abre el brazo de lado para que no lo tape el cuerpo.
-- En la derecha, +Z abre el brazo hacia fuera; en la izquierda, -Z.
local POSES: { [string]: (Model) -> () } = {
	mazo = function(rig)
		gira(rig, "RightShoulder", 80, 0, 35)
		gira(rig, "RightElbow", -30)
		gira(rig, "LeftShoulder", 20, 0, -35)
		gira(rig, "LeftElbow", -50)
	end,
	arco = function(rig)
		gira(rig, "RightShoulder", 90, 0, 8)
		rodaMano(rig, "Right", Vector3.xAxis, 90)
		rodaMano(rig, "Right", Vector3.yAxis, 90)
		gira(rig, "LeftShoulder", 75, 0, -25)
		gira(rig, "LeftElbow", -110)
	end,
	baston = function(rig)
		gira(rig, "RightShoulder", 75, 0, 30)
		rodaMano(rig, "Right", Vector3.zAxis, -90)
		gira(rig, "LeftShoulder", 55, 0, -50)
		gira(rig, "LeftElbow", -50)
	end,
	cerbatana = function(rig)
		gira(rig, "RightShoulder", 75, 0, 30)
		rodaMano(rig, "Right", Vector3.zAxis, -90)
		gira(rig, "LeftShoulder", 20, 0, -35)
		gira(rig, "LeftElbow", -50)
	end,
}

local function jugador(carpeta: Folder, equipo: Equipo, base: Vector3?)
	local rig = rigDe(equipo)
	rig.Parent = carpeta
	local gradoMax = ArmorModels.MAX_GRADE
	ArmorModels.wear(rig, equipo.armadura, equipo.rol, equipo.traje, gradoMax)
	local armaId = equipo.arma or WeaponTools.roleWeapon(equipo.rol, WeaponTools.MAX_LEVEL)
	local herramienta = WeaponTools.build(armaId, equipo.aspecto)
	local mano = rig:FindFirstChild("RightHand") :: BasePart
	local mango = herramienta:FindFirstChild("Handle") :: BasePart
	if mano and mango then
		herramienta.Parent = rig
		local agarre = mano:FindFirstChild("RightGripAttachment") :: Attachment?
		local soldadura = Instance.new("Weld")
		soldadura.Name = "RightGrip"
		soldadura.Part0 = mano
		soldadura.Part1 = mango
		soldadura.C0 = if agarre then agarre.CFrame else CFrame.identity
		soldadura.C1 = herramienta.Grip
		soldadura.Parent = mano
	end
	anclar(rig)
	POSES[equipo.pose](rig)
	local humanoide = rig:FindFirstChildOfClass("Humanoid")
	if humanoide then
		humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	-- De pie en su sitio, mirando a la cámara (+Z) con su giro. Se coloca por la raíz, no por la caja del
	-- modelo, para que el arma y el traje no los levanten del suelo.
	local raiz = rig:FindFirstChild("HumanoidRootPart") :: BasePart
	rig.PrimaryPart = raiz
	local altura = (if humanoide then humanoide.HipHeight else 2) + raiz.Size.Y / 2
	rig:PivotTo(
		CFrame.new((base or ORIGEN) + Vector3.new(equipo.x, altura, equipo.z))
			* CFrame.Angles(0, math.rad(180 + equipo.giro), 0)
	)
	anclar(rig)
end

-- ===================================== Jefes =====================================

local function jefe(carpeta: Folder, datos: { id: string, x: number, z: number, giro: number }, base: Vector3?)
	local boss = Bosses[datos.id]
	local aspecto = table.clone(Monkeys[boss.baseSpecies])
	aspecto.name, aspecto.scale = boss.name, boss.scale
	aspecto.bodyColor, aspecto.faceColor = boss.bodyColor, boss.faceColor
	local modelo =
		MonkeyModels.build(boss.baseSpecies, aspecto, (base or ORIGEN) + Vector3.new(datos.x, 0, datos.z), datos.id)
	MonkeyModels.showPhase(modelo, 3)
	modelo.Name = `Jefe_{datos.id}`
	modelo:PivotTo(modelo:GetPivot() * CFrame.Angles(0, math.rad(180 + datos.giro), 0))
	modelo.Parent = carpeta
	anclar(modelo)
end

-- ===================================== Iluminación y cámara =====================================

local GUARDADAS =
	{ "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "FogColor", "FogEnd", "FogStart" }

local function iluminacion(carpeta: Folder)
	for _, nombre in GUARDADAS do
		carpeta:SetAttribute(`Luz_{nombre}`, (Lighting :: any)[nombre])
	end
	Lighting.ClockTime = 0
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(150, 110, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(175, 120, 140)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 150, 90)
	Lighting.FogColor = Color3.fromRGB(110, 40, 70)
	Lighting.FogStart = 260
	Lighting.FogEnd = 900
end

function Portada.clear()
	local carpeta = Workspace:FindFirstChild(NOMBRE)
	if carpeta then
		for _, nombre in GUARDADAS do
			local valor = carpeta:GetAttribute(`Luz_{nombre}`)
			if valor ~= nil then
				(Lighting :: any)[nombre] = valor
			end
		end
		carpeta:Destroy()
	end
end

function Portada.camara(toma: string?)
	local datos = TOMAS[toma or "principal"]
	assert(datos, `Toma desconocida: {toma}`)
	local camara = Workspace.CurrentCamera
	camara.CameraType = Enum.CameraType.Scriptable
	camara.FieldOfView = 55
	camara.CFrame = CFrame.lookAt(ORIGEN + datos.camara, ORIGEN + datos.objetivo)
end

function Portada.build(variante: string?)
	Portada.clear()
	local carpeta = Instance.new("Folder")
	carpeta.Name = NOMBRE
	-- Dentro del Workspace desde el principio: las uniones de los rigs solo recolocan sus piezas allí.
	carpeta.Parent = Workspace
	iluminacion(carpeta)
	cielo(carpeta)
	volcan(carpeta)
	rayos(carpeta)
	for _, datos in JEFES do
		jefe(carpeta, datos)
		task.wait()
	end
	for _, equipo in EQUIPOS do
		jugador(carpeta, equipo)
		task.wait()
	end
	Portada.camara(variante)
	return carpeta
end

-- ===================================== Fichas de referencia =====================================

-- Un solo personaje (un rol o un jefe) sobre un fondo liso y claro, para que se vea todo el equipo sin
-- nada que lo tape: la referencia que se adjunta a Gemini junto al prompt.
local FICHA = ORIGEN + Vector3.new(0, 0, 700)

function Portada.ficha(id: string)
	Portada.clear()
	local carpeta = Instance.new("Folder")
	carpeta.Name = NOMBRE
	carpeta.Parent = Workspace
	for _, nombre in GUARDADAS do
		carpeta:SetAttribute(`Luz_{nombre}`, (Lighting :: any)[nombre])
	end
	Lighting.ClockTime = 14
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(170, 165, 180)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 165, 180)
	Lighting.ColorShift_Top = Color3.new(1, 1, 1)
	Lighting.FogEnd = 100000
	parte(
		carpeta,
		"Suelo",
		Vector3.new(120, 1, 120),
		CFrame.new(FICHA + Vector3.new(0, -0.5, 0)),
		Color3.fromRGB(96, 92, 108),
		Enum.Material.SmoothPlastic
	).CastShadow =
		true
	for _, lado in { 1, -1 } do
		parte(
			carpeta,
			"Fondo",
			Vector3.new(120, 60, 1),
			CFrame.new(FICHA + Vector3.new(0, 30, 60 * lado)),
			Color3.fromRGB(70, 64, 86)
		)
	end
	local encontrado = false
	for _, equipo in EQUIPOS do
		if equipo.rol == id then
			local copia = table.clone(equipo)
			copia.x, copia.z, copia.giro = 0, 0, 0
			jugador(carpeta, copia, FICHA)
			encontrado = true
		end
	end
	for _, datos in JEFES do
		if datos.id == id then
			jefe(carpeta, { id = id, x = 0, z = 0, giro = 0 }, FICHA)
			encontrado = true
		end
	end
	assert(encontrado, `No hay jugador ni jefe "{id}"`)
	return carpeta
end

-- Cámara de una ficha: devuelve { camara, objetivo } (mundo) para el screen_capture. "frente", "espalda",
-- "izquierda" (tres cuartos) y "arma" (primer plano del arma, solo jugadores). "alto" es lo que mide el
-- personaje: 5 los jugadores, la escala del jefe por 3,4.
function Portada.vista(nombre: string, alto: number?)
	local h = alto or 5
	local d = h * 2.9
	local y = h * 0.5
	local direcciones = {
		frente = Vector3.new(0, 0, d),
		espalda = Vector3.new(0, 0, -d),
		izquierda = Vector3.new(-d * 0.75, 0, d * 0.65),
		arma = Vector3.new(d * 0.35, 0, d * 0.45),
	}
	local dir = direcciones[nombre]
	assert(dir, `Vista desconocida: {nombre}`)
	return { camara = FICHA + Vector3.new(0, y, 0) + dir, objetivo = FICHA + Vector3.new(0, y, 0) }
end

-- Lo que reutiliza Trailer (vídeos): los mismos jugadores, jefes, luz y tablas, sin copiarlos.
Portada.jugador = jugador
Portada.jefe = jefe
Portada.iluminacion = iluminacion
Portada.EQUIPOS = EQUIPOS
Portada.JEFES = JEFES
Portada.GUARDADAS = GUARDADAS

return Portada
